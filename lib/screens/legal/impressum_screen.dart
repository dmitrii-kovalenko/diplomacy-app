import 'package:flutter/material.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impressum')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Angaben gemäß § 5 TMG',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Verantwortlicher:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('Max Mustermann'),
            Text('Musterstraße 1'),
            Text('12345 Musterstadt'),
            Text('Deutschland'),
            SizedBox(height: 16),
            Text(
              'Kontakt:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('E-Mail: kontakt@example.com'),
            Text('Telefon: +49 123 456789'),
            SizedBox(height: 16),
            Text(
              'Haftungsausschluss:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Die Inhalte dieser App wurden mit größter Sorgfalt erstellt. '
              'Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte '
              'kann jedoch keine Gewähr übernommen werden.',
            ),
          ],
        ),
      ),
    );
  }
}
