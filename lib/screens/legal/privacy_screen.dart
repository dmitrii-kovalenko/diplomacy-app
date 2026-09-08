import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutzerklärung')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datenschutzerklärung',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '1. Allgemeine Hinweise',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Die folgenden Hinweise geben einen einfachen Überblick darüber, was mit Ihren personenbezogenen Daten passiert, wenn Sie diese App nutzen. Personenbezogene Daten sind alle Daten, mit denen Sie persönlich identifiziert werden können.',
            ),
            const SizedBox(height: 16),
            Text(
              '2. Datenerfassung in der App',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Die Datenverarbeitung in dieser App erfolgt durch den Betreiber. Dessen Kontaktdaten können Sie dem Impressum entnehmen.\n\n'
              'Einige Daten werden automatisch bei der Nutzung der App erfasst (z. B. IP-Adresse, Geräteinformationen, Uhrzeit des Zugriffs). Diese Daten sind technisch erforderlich, um Ihnen die App bereitzustellen.',
            ),
            const SizedBox(height: 16),
            Text(
              '3. Registrierung und Nutzerkonten',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wenn Sie sich in der App registrieren (z.B. via Google oder Apple Sign-In), speichern wir Ihre E-Mail-Adresse und eine generierte Nutzer-ID. Diese Daten werden ausschließlich zur Verwaltung Ihres Kontos und für den Spielbetrieb genutzt.',
            ),
            const SizedBox(height: 16),
            Text(
              '4. Analyse-Tools (Firebase & Crashlytics)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sofern Sie eingewilligt haben, nutzen wir Google Analytics for Firebase und Firebase Crashlytics, um die Nutzung der App zu analysieren und Fehler zu beheben. Die erhobenen Daten werden anonymisiert verarbeitet und helfen uns, die App-Erfahrung zu verbessern.',
            ),
            const SizedBox(height: 16),
            Text(
              '5. End-to-End-Verschlüsselung (E2EE)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'In privaten Chats verwenden wir eine Ende-zu-Ende-Verschlüsselung. Das bedeutet, dass Nachrichten auf Ihrem Gerät verschlüsselt und erst auf dem Gerät des Empfängers wieder entschlüsselt werden. Der Betreiber hat keinen Zugriff auf den Klartext dieser Nachrichten.',
            ),
            const SizedBox(height: 16),
            Text(
              '6. Ihre Rechte',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sie haben jederzeit das Recht, unentgeltlich Auskunft über Herkunft, Empfänger und Zweck Ihrer gespeicherten personenbezogenen Daten zu erhalten. Sie haben außerdem ein Recht, die Berichtigung oder Löschung dieser Daten zu verlangen. Sie können Ihr Konto und alle damit verbundenen Daten direkt in den Einstellungen der App löschen.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
