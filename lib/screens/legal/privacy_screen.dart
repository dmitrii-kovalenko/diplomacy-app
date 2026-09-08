import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutzerklärung')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datenschutzerklärung',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '1. Verantwortlicher (Art. 13 Abs. 1 lit. a DSGVO)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Max Mustermann\n'
              'Musterstraße 1\n'
              '12345 Musterstadt\n'
              'E-Mail: kontakt@example.com',
            ),
            SizedBox(height: 16),
            Text(
              '2. Erhobene Daten und Zweck der Verarbeitung (Art. 13 Abs. 1 lit. c–e DSGVO)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Wir verarbeiten folgende personenbezogene Daten:\n\n'
              '• E-Mail-Adresse: zur Kontoerstellung und Authentifizierung.\n'
              '• Gerätekennungen (Push-Token): zur Zustellung von Spielbenachrichtigungen.\n'
              '• Spielverlaufsdaten (Spielername, Aktionen): zur Durchführung des Spiels.\n\n'
              'Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung).',
            ),
            SizedBox(height: 16),
            Text(
              '3. Analytik und Crashlytics (nur mit Ihrer Einwilligung)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Wenn Sie zustimmen, verwenden wir Firebase Analytics und Crashlytics '
              '(Google LLC) zur Verbesserung der App. Diese Dienste können Absturzberichte '
              'und anonymisierte Nutzungsstatistiken erheben.\n\n'
              'Rechtsgrundlage: Art. 6 Abs. 1 lit. a DSGVO (Einwilligung).\n'
              'Sie können Ihre Einwilligung jederzeit in den Einstellungen widerrufen.',
            ),
            SizedBox(height: 16),
            Text(
              '4. Datenweitergabe an Dritte (Art. 13 Abs. 1 lit. e DSGVO)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Eine Weitergabe Ihrer Daten an Dritte erfolgt nur, soweit dies zur '
              'Vertragserfüllung erforderlich ist oder Sie eingewilligt haben. '
              'Dienstleister (z. B. Firebase/Google) sind vertraglich zur Einhaltung '
              'des Datenschutzes verpflichtet.',
            ),
            SizedBox(height: 16),
            Text(
              '5. Speicherdauer (Art. 13 Abs. 2 lit. a DSGVO)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Ihre Daten werden gelöscht, sobald sie für den Verarbeitungszweck nicht '
              'mehr erforderlich sind oder Sie Ihr Konto löschen.',
            ),
            SizedBox(height: 16),
            Text(
              '6. Ihre Rechte (Art. 13 Abs. 2 lit. b–d DSGVO)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Sie haben das Recht auf:\n'
              '• Auskunft (Art. 15 DSGVO)\n'
              '• Berichtigung (Art. 16 DSGVO)\n'
              '• Löschung (Art. 17 DSGVO) – nutzen Sie die Funktion „Konto löschen" in den Einstellungen\n'
              '• Einschränkung der Verarbeitung (Art. 18 DSGVO)\n'
              '• Widerspruch (Art. 21 DSGVO)\n'
              '• Beschwerde bei einer Aufsichtsbehörde (Art. 77 DSGVO)',
            ),
          ],
        ),
      ),
    );
  }
}
