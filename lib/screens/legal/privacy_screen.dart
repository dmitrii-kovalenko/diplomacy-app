import 'package:flutter/material.dart';

import 'legal_layout.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScaffold(
      title: 'Datenschutz',
      intro:
          'Ein Überblick darüber, was mit deinen personenbezogenen Daten '
          'passiert, wenn du diese App nutzt.',
      children: [
        LegalHeading('1. Allgemeine Hinweise'),
        LegalBody(
          'Personenbezogene Daten sind alle Daten, mit denen du persönlich '
          'identifiziert werden kannst. Die folgenden Abschnitte erklären, '
          'welche davon wir erheben und wofür.',
        ),
        LegalHeading('2. Datenerfassung in der App'),
        LegalBody(
          'Die Datenverarbeitung in dieser App erfolgt durch den Betreiber. '
          'Dessen Kontaktdaten kannst du dem Impressum entnehmen.',
        ),
        LegalBody(
          'Einige Daten werden automatisch bei der Nutzung der App erfasst '
          '(z. B. IP-Adresse, Geräteinformationen, Uhrzeit des Zugriffs). '
          'Diese Daten sind technisch erforderlich, um dir die App '
          'bereitzustellen.',
        ),
        LegalHeading('3. Registrierung und Nutzerkonten'),
        LegalBody(
          'Wenn du dich in der App registrierst (z. B. via Google oder Apple '
          'Sign-In), speichern wir deine E-Mail-Adresse und eine generierte '
          'Nutzer-ID. Diese Daten werden ausschließlich zur Verwaltung deines '
          'Kontos und für den Spielbetrieb genutzt.',
        ),
        LegalHeading('4. Analyse-Tools (Firebase & Crashlytics)'),
        LegalBody(
          'Sofern du eingewilligt hast, nutzen wir Google Analytics for '
          'Firebase und Firebase Crashlytics, um die Nutzung der App zu '
          'analysieren und Fehler zu beheben. Die erhobenen Daten werden '
          'anonymisiert verarbeitet.',
        ),
        LegalHeading('5. Ende-zu-Ende-Verschlüsselung'),
        LegalBody(
          'In privaten Chats verwenden wir eine Ende-zu-Ende-Verschlüsselung. '
          'Nachrichten werden auf deinem Gerät verschlüsselt und erst auf dem '
          'Gerät des Empfängers wieder entschlüsselt. Der Betreiber hat keinen '
          'Zugriff auf den Klartext dieser Nachrichten.',
        ),
        LegalHeading('6. Deine Rechte'),
        LegalBody(
          'Du hast jederzeit das Recht, unentgeltlich Auskunft über Herkunft, '
          'Empfänger und Zweck deiner gespeicherten personenbezogenen Daten zu '
          'erhalten, sowie ein Recht auf Berichtigung oder Löschung. Dein '
          'Konto und alle damit verbundenen Daten kannst du direkt in den '
          'Einstellungen der App löschen.',
        ),
      ],
    );
  }
}
