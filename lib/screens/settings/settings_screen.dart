import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import '../../services/e2ee_fingerprint.dart' as fp;
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
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _loadFingerprint();
  }

  // Same grouped-by-four rendering as the Mini App's openEncryptionSettings
  // and the bot's /mykey, so a player can read this aloud and the other side
  // can compare it character-for-character. `init()` only ever otherwise ran
  // from ChatBloc, so a player who opens Settings before ever opening a
  // conversation would see no key at all without calling it here too;
  // E2EEService's own memoization makes this a no-op once chat has already
  // initialised it.
  Future<void> _loadFingerprint() async {
    await _e2eeService.init();
    if (!mounted) return;
    final pub = _e2eeService.myPublicKeyBase64;
    if (pub == null) {
      setState(() => _fingerprint = null);
      return;
    }
    final hex = await fp.fingerprint(pub);
    if (!mounted) return;
    setState(() => _fingerprint = fp.formatFingerprint(hex));
  }

  static const Map<String, String> _languages = {
    'en': 'English',
    'ru': 'Русский',
    'uk': 'Українська',
    'de': 'Deutsch',
    'cv': 'Чӑвашла',
    'eo': 'Esperanto',
  };

  Future<void> _resetKey() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.settingsResetKeyTitle,
      message: loc.settingsResetKeyMessage,
      confirmLabel: loc.settingsResetKeyConfirm,
      destructive: true,
    );
    if (!ok) return;

    setState(() => _isResetting = true);
    await _e2eeService.resetKey();
    if (!mounted) return;
    setState(() => _isResetting = false);
    await _loadFingerprint();
    if (!mounted) return;
    showToast(context, AppLocalizations.of(context)!.settingsNewKeyGeneratedToast);
  }

  Future<void> _copyFingerprint() async {
    final value = _fingerprint;
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showToast(context, AppLocalizations.of(context)!.settingsFingerprintCopiedToast);
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
    final loc = AppLocalizations.of(context)!;
    final lang = await showChoiceSheet<String>(
      context,
      title: loc.language,
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
        AppLocalizations.of(context)!.settingsLanguageSyncError,
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.settingsSignOutTitle,
      message: loc.settingsSignOutMessage,
      confirmLabel: loc.settingsSignOutConfirm,
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
    final loc = AppLocalizations.of(context)!;
    final ok = await confirm(
      context,
      title: loc.settingsDeleteAccountTitle,
      message: loc.settingsDeleteAccountMessage,
      confirmLabel: loc.settingsDeleteAccountConfirm,
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
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.settingsDeleteAccountError,
            isError: true);
      }
    }
  }

  Future<void> _launchCommunity() async {
    final url = Uri.parse('https://t.me/diplomacy_community');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showToast(context, AppLocalizations.of(context)!.settingsCommunityLinkError,
            isError: true);
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.settingsGenericLinkError,
            isError: true);
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
        ? loc.settingsFingerprintNotGenerated
        : loc.settingsE2eeActive;

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
                  title: loc.settingsLinkedDevicesTitle,
                  subtitle: loc.settingsLinkedDevicesSubtitle,
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
              footer: loc.settingsSecurityFooter,
              children: [
                InsetRow(
                  title: loc.settingsE2eeTitle,
                  subtitle: fingerprint,
                  icon: CupertinoIcons.lock_fill,
                  iconColor: c.green,
                  showChevron: false,
                  trailing: StatusPill(
                    pub == null ? loc.settingsE2eeNotSetUp : loc.settingsE2eeActive,
                    tone: pub == null
                        ? StatusTone.warning
                        : StatusTone.positive,
                  ),
                ),
                if (pub != null)
                  InsetRow(
                    title: loc.settingsFingerprintLabel,
                    subtitle: _fingerprint ?? loc.settingsComputingEllipsis,
                    icon: CupertinoIcons.number,
                    iconColor: c.green,
                    showChevron: false,
                    onTap: _fingerprint == null ? null : _copyFingerprint,
                    trailing: _fingerprint == null
                        ? null
                        : Icon(CupertinoIcons.doc_on_doc,
                            size: 15, color: c.labelTertiary),
                  ),
                InsetRow(
                  title: loc.settingsResetKeyRowTitle,
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
              header: loc.settingsLegalSectionHeader,
              children: [
                InsetRow(
                  title: loc.legalImpressumTitle,
                  icon: CupertinoIcons.building_2_fill,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImpressumScreen()),
                  ),
                ),
                InsetRow(
                  title: loc.legalPrivacyTitle,
                  icon: CupertinoIcons.hand_raised_fill,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                InsetRow(
                  title: loc.settingsLicensesTitle,
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
                  title: loc.settingsDeleteAccountConfirm,
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
