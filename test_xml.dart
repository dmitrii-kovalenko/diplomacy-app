import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  final file = File('../Conspa/DjangoProject/assets/maps/europe_extended.svg');
  final content = file.readAsStringSync();
  try {
    XmlDocument.parse(content);
    print("XML PARSED SUCCESSFULLY");
  } catch (e) {
    print("XML PARSE ERROR: $e");
  }
}
