import 'package:flutter/material.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impressum')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Angaben gemäß § 5 TMG',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Verantwortlicher:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Max Mustermann'),
            const Text('Musterstraße 1'),
            const Text('12345 Musterstadt'),
            const Text('Deutschland'),
            const SizedBox(height: 16),
            Text(
              'Kontakt:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('E-Mail: kontakt@example.com'),
            const Text('Telefon: +49 123 456789'),
            const SizedBox(height: 16),
            Text(
              'Haftungsausschluss:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
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
