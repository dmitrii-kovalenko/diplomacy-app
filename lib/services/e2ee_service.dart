import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  final _storage = const FlutterSecureStorage();
  final _ecdh = Ecdh.p256(length: 32);
  final _aesGcm = AesGcm.with256bits();
  
  EcKeyPair? _keyPair;
  String? myPublicKeyBase64;

  // Memoizes `_doInit()` for the life of the app, not just for the span of
  // one call: a second `ChatBloc` created later in the same launch — after
  // the first has already finished — must not re-run `_repairPublication()`
  // (an extra `GET`/`POST /api/me/key/` round trip for no reason). A launch
  // that fails is retried: the identity check in the `catchError` below only
  // clears the memo when it still points at *this* attempt, so a concurrent
  // `resetKey()` that has already installed a fresh attempt is never
  // clobbered by an older one finishing (successfully or not) after it.
  Future<void>? _initFuture;

  Future<void> init() {
    final cached = _initFuture;
    if (cached != null) return cached;
    final future = _doInit();
    _initFuture = future;
    return future.catchError((Object e) {
      if (identical(_initFuture, future)) _initFuture = null;
      throw e;
    });
  }

  Future<void> _doInit() async {
    final privKeyBase64 = await _storage.read(key: 'e2ee_priv_key');
    if (privKeyBase64 != null) {
      final privBytes = base64Decode(privKeyBase64);
      _keyPair = await _ecdh.newKeyPairFromSeed(privBytes);
      final pubKey = await _keyPair!.extractPublicKey();
      myPublicKeyBase64 = base64Encode([4, ...pubKey.x, ...pubKey.y]);
      await _repairPublication();
    } else {
      _keyPair = await _ecdh.newKeyPair();
      final kpData = await _keyPair!.extract();
      final privBytes = kpData.d;
      await _storage.write(key: 'e2ee_priv_key', value: base64Encode(privBytes));

      final pubKey = kpData.publicKey;
      // Uncompressed X9.62 format: 0x04 || X || Y
      final rawPub = [4, ...pubKey.x, ...pubKey.y];
      myPublicKeyBase64 = base64Encode(rawPub);

      final dio = AuthService().dio;
      try {
        await dio.post('/api/me/key/', data: {'public_key': myPublicKeyBase64});
      } catch (e) {
        debugPrint('Failed to upload public key: $e');
      }
    }
  }

  // Ports crypto.js's ensureEncryptionReady repair path: re-checks the
  // server once per launch and republishes when it disagrees, so a key that
  // failed to upload once (offline at first run, a transient 500, an
  // expired token) is not silently stuck server-side as "no key" forever —
  // that degrades every DM with this player to server-readable Fernet with
  // no signal to either side. Only ever posts the key this instance already
  // holds; a failure here (still offline, etc.) keeps the local key as-is.
  // For an account with no linked Telegram id, `GET /api/me/key/` 400s
  // every time (`game/api/keys.py` requires a `tg_id`) — not a meaningful
  // check in that case, just a harmless no-op caught below.
  Future<void> _repairPublication() async {
    final dio = AuthService().dio;
    try {
      final response = await dio.get('/api/me/key/');
      final data = response.data as Map;
      final hasKey = data['has_key'] == true;
      final serverKey = data['public_key'] as String?;
      if (!hasKey || serverKey != myPublicKeyBase64) {
        await dio.post('/api/me/key/', data: {'public_key': myPublicKeyBase64});
      }
    } catch (e) {
      debugPrint('Key repair check failed, keeping local key: $e');
    }
  }

  Future<void> resetKey() async {
    final dio = AuthService().dio;
    try {
      await dio.post('/api/me/key/reset/');
    } catch (e) {
      debugPrint('Failed to reset key on server: $e');
    }
    await _storage.delete(key: 'e2ee_priv_key');
    _keyPair = null;
    myPublicKeyBase64 = null;
    // Drop any completed init() memo — this is a deliberate new key, not a
    // re-check of the old one. If an old _doInit() is still in flight, its
    // own completion won't clobber the fresh attempt init() is about to
    // install: the identity check in init()'s catchError only clears the
    // memo when it still points at the attempt that failed.
    _initFuture = null;
    await init();
  }

  Future<SecretKey> deriveSharedSecret(String remotePubKeyBase64) async {
    if (_keyPair == null) await init();
    
    final rawRemote = base64Decode(remotePubKeyBase64);
    // Remove 0x04 prefix if present
    final remoteBytes = rawRemote.length == 65 && rawRemote[0] == 4 ? rawRemote.sublist(1) : rawRemote;
    
    final x = remoteBytes.sublist(0, 32);
    final y = remoteBytes.sublist(32, 64);
    final remoteKey = EcPublicKey(x: x, y: y, type: KeyPairType.p256);
    
    return await _ecdh.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: remoteKey,
    );
  }

  Future<Map<String, String>> encryptMessage(String text, String remotePubKeyBase64) async {
    final sharedSecret = await deriveSharedSecret(remotePubKeyBase64);
    
    // Generate IV (Nonce) for AES-GCM (12 bytes)
    final ivBytes = _aesGcm.newNonce(); // this is 12 bytes
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(text),
      secretKey: sharedSecret,
      nonce: ivBytes,
    );
    
    return {
      'ciphertext': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
      'iv': base64Encode(ivBytes),
    };
  }

  // Returns null on failure — never a placeholder string. The caller (chat
  // history / websocket handler) turns a null into a locked-bubble state;
  // it must never render literally as message text.
  Future<String?> decryptMessage(String ciphertextBase64, String ivBase64, String senderPubKeyBase64) async {
    try {
      final sharedSecret = await deriveSharedSecret(senderPubKeyBase64);
      final rawCipher = base64Decode(ciphertextBase64);
      final macLength = _aesGcm.macAlgorithm.macLength;
      final cipherText = rawCipher.sublist(0, rawCipher.length - macLength);
      final macBytes = rawCipher.sublist(rawCipher.length - macLength);
      
      final secretBox = SecretBox(
        cipherText,
        nonce: base64Decode(ivBase64),
        mac: Mac(macBytes),
      );
      
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: sharedSecret,
      );
      
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return null;
    }
  }

  Future<String?> exportKey() async {
    final privBase64 = await _storage.read(key: 'e2ee_priv_key');
    if (privBase64 == null) return null;
    
    final privBytes = base64Decode(privBase64);
    final keyPair = await _ecdh.newKeyPairFromSeed(privBytes);
    final pubKey = await keyPair.extractPublicKey();
    
    String b64url(List<int> bytes) {
      return base64UrlEncode(bytes).replaceAll('=', '');
    }
    
    final jwk = {
      "kty": "EC",
      "crv": "P-256",
      "d": b64url(privBytes),
      "x": b64url(pubKey.x),
      "y": b64url(pubKey.y),
      "ext": true
    };
    return jsonEncode(jwk);
  }

  Future<void> importKey(String input) async {
    try {
      input = input.trim();
      if (input.startsWith('eyJ')) {
        try {
          String normalized = input;
          while (normalized.length % 4 != 0) normalized += '=';
          input = utf8.decode(base64Decode(normalized));
        } catch (_) {}
      }

      List<int> privBytes;
      if (input.startsWith('{')) {
        final jwk = jsonDecode(input);
        if (jwk['kty'] != 'EC' || jwk['crv'] != 'P-256' || jwk['d'] == null) {
          throw Exception('Invalid JWK format');
        }
        String dStr = jwk['d'];
        while (dStr.length % 4 != 0) {
          dStr += '=';
        }
        privBytes = base64Url.decode(dStr);
      } else {
        privBytes = base64Decode(input);
      }
      
      _keyPair = await _ecdh.newKeyPairFromSeed(privBytes);
      final pubKey = await _keyPair!.extractPublicKey();
      myPublicKeyBase64 = base64Encode([4, ...pubKey.x, ...pubKey.y]);
      
      await _storage.write(key: 'e2ee_priv_key', value: base64Encode(privBytes));
      
      final dio = AuthService().dio;
      try {
        await dio.post('/api/me/key/', data: {'public_key': myPublicKeyBase64});
      } catch (e) {
        debugPrint('Failed to upload imported public key: $e');
      }
    } catch (e) {
      throw Exception('Invalid key format');
    }
  }
}
