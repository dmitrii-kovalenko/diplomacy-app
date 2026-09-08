import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import '../../providers/locale_provider.dart';
import '../legal/impressum_screen.dart';
import '../legal/privacy_screen.dart';
import '../auth/login_screen.dart';
import 'link_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final E2EEService _e2eeService = E2EEService();
  String _selectedLanguage = 'English';
  bool _isResetting = false;

  void _resetKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Encryption Key?'),
        content: const Text('WARNING: You will lose access to all your previous End-to-End Encrypted chat history. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Reset', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isResetting = true);
      await _e2eeService.resetKey();
      setState(() => _isResetting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Encryption keys reset successfully.')));
      }
    }
  }

  void _changeLanguage() async {
    final lang = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          'en',
          'ru',
          'uk',
          'de',
          'cv',
          'eo',
        ].map((l) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, l),
          child: Text(l),
        )).toList(),
      ),
    );

    if (lang != null && lang != _selectedLanguage) {
      if (!mounted) return;
      setState(() => _selectedLanguage = lang);
      // Update locale
      Provider.of<LocaleProvider>(context, listen: false).setLocale(Locale(lang));
      
      // Optional: sync to backend
      try {
        await _authService.dio.post('/api/settings/language/', data: {'language': lang});
      } catch (_) {}
    }
  }

  void _logout() async {
    await _authService.logout();
    // Normally you'd route back to login here. We'll rely on the app's main router listening to auth state.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: const Text(
          'Diese Aktion ist unwiderruflich. Dein Konto und alle zugehörigen Daten werden dauerhaft gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Konto löschen', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Löschen des Kontos: $e')),
          );
        }
      }
    }
  }

  void _launchCommunity() async {
    final url = Uri.parse('https://t.me/diplomacy_community'); // example URL
    try {
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open community link.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pub = _e2eeService.myPublicKeyBase64;
    final pubKeyPreview = pub != null ? (pub.length > 16 ? '${pub.substring(0, 16)}...' : pub) : 'Not generated';

    final loc = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(loc.preferences, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(loc.language),
                  subtitle: Text(_selectedLanguage),
                  onTap: _changeLanguage,
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Konto verknüpfen / Link Accounts'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(loc.security, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('End-to-End Encryption'),
                  subtitle: Text('Public Key: $pubKeyPreview'),
                ),
                ListTile(
                  leading: Icon(Icons.refresh, color: errorColor),
                  title: Text('Reset Key Pair', style: TextStyle(color: errorColor)),
                  onTap: _isResetting ? null : _resetKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(loc.about, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(loc.joinTheCommunity),
                  onTap: _launchCommunity,
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(loc.appInfo),
                  subtitle: Text(loc.version),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Rechtliches', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('Impressum'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImpressumScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Datenschutzerklärung'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.source),
                  title: const Text('Open-Source Lizenzen'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LicensePage(
                        applicationName: 'Conspa Diplomacy',
                        applicationVersion: '1.0.0',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(loc.logOut),
                  onTap: _logout,
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: errorColor),
                  title: Text('Konto löschen', style: TextStyle(color: errorColor)),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
