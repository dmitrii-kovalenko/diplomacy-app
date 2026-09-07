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

  Future<void> init() async {
    final privKeyBase64 = await _storage.read(key: 'e2ee_priv_key');
    if (privKeyBase64 != null) {
      final privBytes = base64Decode(privKeyBase64);
      _keyPair = await _ecdh.newKeyPairFromSeed(privBytes);
      final pubKey = await _keyPair!.extractPublicKey();
      myPublicKeyBase64 = base64Encode([4, ...pubKey.x, ...pubKey.y]);
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

  Future<String> decryptMessage(String ciphertextBase64, String ivBase64, String senderPubKeyBase64) async {
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
      return '[Decryption Failed]';
    }
  }
}
