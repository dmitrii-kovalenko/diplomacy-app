import 'package:flutter/material.dart';

import 'legal_layout.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: 'Privacy Policy',
      intro:
          'An overview of what happens to your personal data '
          'when you use this app.',
      children: [
        LegalHeading('1. General Information'),
        LegalBody(
          'Personal data refers to any data that can be used to personally '
          'identify you. The following sections explain which data we collect '
          'and for what purpose.',
        ),
        LegalHeading('2. Data Collection in the App'),
        LegalBody(
          'Data processing in this app is carried out by the operator. '
          'You can find their contact details in the Legal Notice (Impressum).',
        ),
        LegalBody(
          'Some data is collected automatically when you use the app '
          '(e.g. IP address, device info, access time). '
          'This data is technically necessary to provide the app to you.',
        ),
        LegalHeading('3. Registration and User Accounts'),
        LegalBody(
          'When you register in the app (e.g. via Google or Apple Sign-In), '
          'we store your email address and a generated user ID. This data is '
          'used exclusively to manage your account and for game operations.',
        ),
        LegalHeading('4. Analysis Tools (Firebase & Crashlytics)'),
        LegalBody(
          'If you have given your consent, we use Google Analytics for Firebase '
          'and Firebase Crashlytics to analyze app usage and fix crashes. '
          'The collected data is processed anonymously.',
        ),
        LegalHeading('5. End-to-End Encryption'),
        LegalBody(
          'In private chats, we use end-to-end encryption. Messages are encrypted '
          'on your device and only decrypted on the recipient\'s device. '
          'The operator has no access to the plaintext of these messages.',
        ),
        LegalHeading('6. Your Rights'),
        LegalBody(
          'You have the right to obtain information free of charge about the '
          'origin, recipient, and purpose of your stored personal data at any '
          'time, as well as a right to correction or deletion. You can delete '
          'your account and all associated data directly in the app settings.',
        ),
      ],
    );
  }
}
