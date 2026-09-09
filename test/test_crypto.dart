import 'package:cryptography/cryptography.dart';
import 'dart:convert';

void main() async {
  final bytes = base64Decode("SGVsbG8=");
  final hash = await Sha256().hash(bytes);
  print(hash.bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
}
