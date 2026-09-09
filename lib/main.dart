import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/nickname_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_kit.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  // Handle background message
}

/// Shows a consent sheet and waits for the user's choice.
/// Returns `true` if analytics consent was granted, `false` otherwise.
Future<bool> _showConsentSheet(BuildContext context) async {
  bool analyticsEnabled = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).bgElevated,
    barrierColor: AppColors.of(context).scrim,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      final t = Theme.of(ctx).textTheme;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AppSheet(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Privacy Settings',
                              style: t.displaySmall),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'You decide which data we process. You can change '
                            'this at any time in the settings.',
                            style:
                                t.bodyMedium?.copyWith(color: c.labelSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    InsetSection(
                      children: [
                        const InsetSwitchRow(
                          title: 'Necessary',
                          subtitle:
                              'Required for the core functions of the app.',
                          value: true,
                          onChanged: null,
                        ),
                        InsetSwitchRow(
                          title: 'Analytics & Crashlytics',
                          subtitle:
                              'Hilft uns, Abstürze zu beheben und die App zu '
                              'verbessern.',
                          value: analyticsEnabled,
                          onChanged: (val) =>
                              setState(() => analyticsEnabled = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter),
                      child: AppButton(
                        'Save',
                        onPressed: () =>
                            Navigator.of(ctx).pop(analyticsEnabled),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  return result ?? false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const DiplomacyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DiplomacyApp extends StatelessWidget {
  const DiplomacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final platform = defaultTargetPlatform;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hegemony',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(platform),
      darkTheme: AppTheme.dark(platform),
      themeMode: AppTheme.themeMode,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const InitializerScreen(),
    );
  }
}

class InitializerScreen extends StatefulWidget {
  const InitializerScreen({super.key});

  @override
  State<InitializerScreen> createState() => _InitializerScreenState();
}

class _InitializerScreenState extends State<InitializerScreen> {
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      String? consentValue;
      String? token;
      try {
        consentValue = await _storage.read(key: 'analytics_consent');
        token = await _storage.read(key: 'access_token');
      } catch (e) {
        // If Android Keystore is corrupted due to reinstall, wipe it to recover
        await _storage.deleteAll();
      }

      if (!mounted) return;

      if (consentValue == null) {
        // Wait for first frame to render before showing a bottom sheet
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        final granted = await _showConsentSheet(context);
        await _storage.write(
          key: 'analytics_consent',
          value: granted ? 'true' : 'false',
        );
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
      }

      if (token == null) {
        _navigateTo(const LoginScreen());
        return;
      }

      final me = await _authService.fetchMe();
      if (!mounted) return;

      // Initialize Push Notifications if authenticated
      await PushService().init();

      if (me['nickname'] == null || me['nickname'].toString().isEmpty) {
        _navigateTo(const NicknameScreen());
      } else {
        _navigateTo(const LobbyScreen());
        // Handle initial notification after navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PushService().handleInitialMessage();
        });
      }
    } catch (e) {
      if (!mounted) return;
      // If it's explicitly a 401, the interceptor would have logged us out.
      // If the tokens are gone, we are truly logged out.
      final currentToken = await _storage.read(key: 'access_token').catchError((_) => null);
      if (currentToken == null) {
        _navigateTo(const LoginScreen());
      } else {
        // Network error or 500. Do not log out! Just show a retry button or go to lobby in offline mode.
        // For now, let's just show an error state that lets them retry.
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Connection Error'),
            content: const Text('Could not connect to the server.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _checkAuth(); // Retry
                },
                child: const Text('Retry'),
              )
            ],
          ),
        );
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: BrandMark(showActivity: true));
  }
}

/// The launch identity: one gold seal, the wordmark, and — while something is
/// loading — a quiet activity indicator. Reused by the login screen so the
/// transition out of launch has nothing to jump.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.showActivity = false});

  final bool showActivity;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 76,
            width: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.accent.withOpacity(0.35), width: 1),
            ),
            child: Icon(Icons.shield_outlined, size: 38, color: c.accent),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'HEGEMONY',
            style: t.titleLarge?.copyWith(
              color: c.labelPrimary,
              letterSpacing: 6,
              fontWeight: AppTypography.semibold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Negotiate. Ally. Betray.',
            style: t.bodySmall?.copyWith(
              color: c.labelTertiary,
              letterSpacing: 0.4,
            ),
          ),
          if (showActivity) ...[
            const SizedBox(height: AppSpacing.huge),
            const AppLoader(),
          ],
        ],
      ),
    );
  }
}
