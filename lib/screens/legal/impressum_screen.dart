import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'legal_layout.dart';

/// The German Impressum requirement (§ 5 TMG) prescribes a specific legal
/// form for this page. Its title, section headings and fact labels are
/// ordinary UI chrome and are localized below, but the substantive content —
/// the responsible party's address, the contact details and the disclaimer
/// prose — is left in English in every locale rather than machine-translated.
/// That content is a legal statement, not copy, and mistranslating it would
/// misrepresent what it legally says; the acceptance criteria for this ticket
/// deliberately do not require these screens to be English-free in other
/// locales.
class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return LegalScaffold(
      title: loc.legalImpressumTitle,
      intro: 'Information in accordance with § 5 TMG.',
      children: [
        LegalHeading(loc.legalImpressumResponsiblePartyHeading),
        LegalFact(
          label: loc.legalImpressumAddressLabel,
          lines: const [
            'Max Mustermann',
            'Musterstraße 1',
            '12345 Musterstadt',
            'Deutschland',
          ],
        ),
        LegalFact(
          label: loc.legalImpressumContactLabel,
          lines: const [
            'kontakt@example.com',
            '+49 123 456789',
          ],
        ),
        LegalHeading(loc.legalImpressumDisclaimerHeading),
        const LegalBody(
          'The contents of this app were created with the utmost care. However, '
          'no guarantee can be given for the accuracy, completeness, or '
          'timeliness of the content.',
        ),
      ],
    );
  }
}
