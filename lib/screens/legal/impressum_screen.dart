import 'package:flutter/material.dart';

import 'legal_layout.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: 'Impressum',
      intro: 'Angaben gemäß § 5 TMG.',
      children: [
        LegalHeading('Verantwortlicher'),
        LegalFact(
          label: 'Anschrift',
          lines: [
            'Max Mustermann',
            'Musterstraße 1',
            '12345 Musterstadt',
            'Deutschland',
          ],
        ),
        LegalFact(
          label: 'Kontakt',
          lines: [
            'kontakt@example.com',
            '+49 123 456789',
          ],
        ),
        LegalHeading('Haftungsausschluss'),
        LegalBody(
          'Die Inhalte dieser App wurden mit größter Sorgfalt erstellt. Für '
          'die Richtigkeit, Vollständigkeit und Aktualität der Inhalte kann '
          'jedoch keine Gewähr übernommen werden.',
        ),
      ],
    );
  }
}
