import 'package:flutter_test/flutter_test.dart';

import 'package:diplomacy_app/services/e2ee_fingerprint.dart';

void main() {
  // Vector obtained by running the server's `game/services/crypto.py`
  // `fingerprint()` on this exact base64 public key — see the doc comment
  // on `fingerprint()` in `lib/services/e2ee_fingerprint.dart`. If this test
  // ever needs updating, regenerate the vector from the Python side again;
  // never hand-adjust the expected string.
  const publicKey =
      'BGsX0fLhLEJH+Lzm5WOkQPJ3A32BLeszoPShOUXYmMKWT+NC4v4af5uO5+tKfA'
      '+eFivOM1drMV7Oy7ZAaDe/UfU=';
  const expectedHex = '698bea63dc44a344663ff1429aea1084';
  const expectedGrouped = '698b ea63 dc44 a344 663f f142 9aea 1084';

  test('fingerprint matches the server and Mini App implementations', () async {
    final hex = await fingerprint(publicKey);
    expect(hex, expectedHex);
    expect(hex.length, 32);
  });

  test('formatFingerprint groups by four exactly like crypto.js', () {
    expect(formatFingerprint(expectedHex), expectedGrouped);
  });
}
