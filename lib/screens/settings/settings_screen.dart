import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import '../../providers/locale_provider.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
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

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(loc.preferences, style: const TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(loc.language),
            subtitle: Text(_selectedLanguage),
            onTap: _changeLanguage,
          ),
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text(loc.security, style: const TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('End-to-End Encryption'),
            subtitle: Text('Public Key: $pubKeyPreview'),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.red),
            title: const Text('Reset Key Pair', style: TextStyle(color: Colors.red)),
            onTap: _isResetting ? null : _resetKey,
          ),
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text(loc.about, style: const TextStyle(fontWeight: FontWeight.bold))),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(loc.logOut),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
