import 'package:flutter/material.dart';

import 'legal_layout.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: 'Legal Notice (Impressum)',
      intro: 'Information in accordance with § 5 TMG.',
      children: [
        LegalHeading('Responsible Party'),
        LegalFact(
          label: 'Address',
          lines: [
            'Max Mustermann',
            'Musterstraße 1',
            '12345 Musterstadt',
            'Deutschland',
          ],
        ),
        LegalFact(
          label: 'Contact',
          lines: [
            'kontakt@example.com',
            '+49 123 456789',
          ],
        ),
        LegalHeading('Disclaimer'),
        LegalBody(
          'The contents of this app were created with the utmost care. However, '
          'no guarantee can be given for the accuracy, completeness, or '
          'timeliness of the content.',
        ),
      ],
    );
  }
}
