import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// The out-of-band verification string two players compare to be sure no one
/// is sitting between them: `sha256(raw uncompressed P-256 point)[:16]`,
/// lowercase hex. Every client hashes the exact same bytes the server stores
/// (`UserPublicKey.public_key`, the base64 of `0x04 || X || Y`), so this must
/// stay byte-for-byte identical to the other two implementations:
///   - server: `game/services/crypto.py` `fingerprint()`
///   - Mini App: `assets/game/crypto.js` `_fingerprint()`
///
/// Known-good vector, obtained by running `crypto.py`'s `fingerprint()`
/// directly (not by inspection — the whole point of this module is that
/// eyeballing the algorithm is not enough):
///   public key (base64): BGsX0fLhLEJH+Lzm5WOkQPJ3A32BLeszoPShOUXYmMKWT+NC4v4af5uO5+tKfA+eFivOM1drMV7Oy7ZAaDe/UfU=
///   fingerprint:          698bea63dc44a344663ff1429aea1084
///   grouped:              698b ea63 dc44 a344 663f f142 9aea 1084
/// See `test/e2ee_fingerprint_test.dart` for the test that pins this.
Future<String> fingerprint(String base64PublicKey) async {
  final bytes = base64Decode(base64PublicKey);
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .take(16)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Groups a 32-character fingerprint hex string into 4-character blocks
/// separated by single spaces, matching `crypto.js`'s
/// `fp.replace(/(.{4})/g, "$1 ").trim()` so the two clients render the same
/// string for a player to read aloud or compare.
String formatFingerprint(String hex) {
  final groups = <String>[];
  for (var i = 0; i < hex.length; i += 4) {
    final end = (i + 4 < hex.length) ? i + 4 : hex.length;
    groups.add(hex.substring(i, end));
  }
  return groups.join(' ');
}
