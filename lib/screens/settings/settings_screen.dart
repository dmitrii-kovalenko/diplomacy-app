import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../legal/impressum_screen.dart';
import '../legal/privacy_screen.dart';
import '../auth/login_screen.dart';
import 'link_account_screen.dart';

/// Settings, as grouped sections.
///
/// Current values sit inline on the trailing edge so nothing has to be opened
/// to be read, related options share a section, and the two destructive
/// actions live alone at the very bottom in red — both behind a confirmation.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final E2EEService _e2eeService = E2EEService();
  bool _isResetting = false;

  static const Map<String, String> _languages = {
    'en': 'English',
    'ru': 'Русский',
    'uk': 'Українська',
    'de': 'Deutsch',
    'cv': 'Чӑвашла',
    'eo': 'Esperanto',
  };

  Future<void> _resetKey() async {
    final ok = await confirm(
      context,
      title: 'Reset encryption key?',
      message:
          'You will lose access to every end-to-end encrypted conversation '
          'you have had so far. This cannot be undone.',
      confirmLabel: 'Reset key',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _isResetting = true);
    await _e2eeService.resetKey();
    if (!mounted) return;
    setState(() => _isResetting = false);
    showToast(context, 'A new key pair was generated.');
  }

  /// Maps a Flutter locale code to the code `settings.LANGUAGES` on the
  /// server accepts. Ukrainian is the one mismatch: the server deliberately
  /// registers it as `ua`, not the ISO `uk` (see the comment on `LANGUAGES`
  /// in `DjangoProject/settings.py`), because devices already advertise
  /// `Accept-Language: uk` for auto-detection and the in-app switch needed a
  /// code that would never collide with that. Every other code is identity.
  static String _serverLanguageCode(String flutterCode) =>
      flutterCode == 'uk' ? 'ua' : flutterCode;

  Future<void> _changeLanguage(String current) async {
    final lang = await showChoiceSheet<String>(
      context,
      title: 'Language',
      selected: current,
      options: [
        for (final e in _languages.entries)
          (value: e.key, label: e.value, detail: null),
      ],
    );
    if (lang == null || lang == current) return;
    if (!mounted) return;

    Provider.of<LocaleProvider>(context, listen: false)
        .setLocale(Locale(lang));

    try {
      await _authService.dio.post('/api/settings/language/',
          data: {'language': _serverLanguageCode(lang)});
    } catch (_) {
      if (!mounted) return;
      showToast(
        context,
        'Could not sync the language to your account — it will only apply '
        'on this device for now.',
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    final ok = await confirm(
      context,
      title: 'Sign out?',
      message: 'Your games stay where they are. You can sign back in anytime.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await confirm(
      context,
      title: 'Konto löschen?',
      message:
          'Diese Aktion ist unwiderruflich. Dein Konto und alle zugehörigen '
          'Daten werden dauerhaft gelöscht.',
      confirmLabel: 'Konto löschen',
      cancelLabel: 'Abbrechen',
      destructive: true,
    );
    if (!ok) return;

    try {
      await _authService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        showToast(context, 'Fehler beim Löschen des Kontos: $e', isError: true);
      }
    }
  }

  Future<void> _launchCommunity() async {
    final url = Uri.parse('https://t.me/diplomacy_community');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showToast(context, 'Could not open the community link.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Could not open the link. $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    final currentLang =
        Provider.of<LocaleProvider>(context).locale?.languageCode ?? 'en';

    final pub = _e2eeService.myPublicKeyBase64;
    final fingerprint = pub == null
        ? 'Not generated'
        : 'Active';

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: c.bgBase,
            title: Text(loc.settings),
          ),
          SliverList.list(children: [
            InsetSection(
              header: loc.preferences,
              children: [
                InsetRow(
                  title: loc.language,
                  icon: CupertinoIcons.globe,
                  value: _languages[currentLang] ?? 'English',
                  onTap: () => _changeLanguage(currentLang),
                ),
                InsetRow(
                  title: 'Linked devices',
                  subtitle: 'Use one account on phone, web and Telegram',
                  icon: CupertinoIcons.link,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LinkAccountScreen()),
                  ),
                ),
              ],
            ),
            InsetSection(
              header: loc.security,
              footer:
                  'Private conversations are encrypted on your device. We '
                  'never hold the key that opens them.',
              children: [
                InsetRow(
                  title: 'End-to-end encryption',
                  subtitle: fingerprint,
                  icon: CupertinoIcons.lock_fill,
                  iconColor: c.green,
                  showChevron: false,
                  trailing: StatusPill(
                    pub == null ? 'Not set up' : 'Active',
                    tone: pub == null
                        ? StatusTone.warning
                        : StatusTone.positive,
                  ),
                ),
                InsetRow(
                  title: 'Reset key pair',
                  icon: CupertinoIcons.arrow_2_circlepath,
                  destructive: true,
                  showChevron: false,
                  onTap: _isResetting ? null : _resetKey,
                  trailing: _isResetting
                      ? const CupertinoActivityIndicator(radius: 8)
                      : null,
                ),
              ],
            ),
            InsetSection(
              header: loc.about,
              children: [
                InsetRow(
                  title: loc.joinTheCommunity,
                  icon: CupertinoIcons.person_2_fill,
                  onTap: _launchCommunity,
                ),
                InsetRow(
                  title: loc.appInfo,
                  icon: CupertinoIcons.info_circle_fill,
                  value: AppConfig.appVersion,
                  showChevron: false,
                ),
              ],
            ),
            InsetSection(
              header: 'Rechtliches',
              children: [
                InsetRow(
                  title: 'Legal Notice (Impressum)',
                  icon: CupertinoIcons.building_2_fill,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImpressumScreen()),
                  ),
                ),
                InsetRow(
                  title: 'Privacy Policy',
                  icon: CupertinoIcons.hand_raised_fill,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                InsetRow(
                  title: 'Open-Source Lizenzen',
                  icon: CupertinoIcons.doc_text_fill,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Theme(
                        data: Theme.of(context),
                        child: LicensePage(
                          applicationName: AppConfig.appName,
                          applicationVersion: AppConfig.appVersion,
                          applicationIcon: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Icon(Icons.shield_outlined,
                                size: 40, color: c.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            InsetSection(
              children: [
                InsetRow(
                  title: loc.logOut,
                  icon: CupertinoIcons.square_arrow_right,
                  showChevron: false,
                  onTap: _logout,
                ),
                InsetRow(
                  title: 'Konto löschen',
                  icon: CupertinoIcons.trash_fill,
                  destructive: true,
                  showChevron: false,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter, vertical: AppSpacing.xxxl),
              child: Text(
                '${AppConfig.appName} ${AppConfig.appVersion}',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: c.labelTertiary),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
