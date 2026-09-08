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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background message
}

/// Shows a consent bottom sheet and waits for the user's choice.
/// Returns `true` if analytics consent was granted, `false` otherwise.
Future<bool> _showConsentSheet(BuildContext context) async {
  bool analyticsEnabled = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datenschutz-Einstellungen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Diese App verwendet Cookies und ähnliche Technologien, um Ihnen die bestmögliche Erfahrung zu bieten.',
                ),
                const SizedBox(height: 16),
                const SwitchListTile(
                  value: true,
                  onChanged: null, // cannot be disabled
                  title: Text('Notwendig'),
                  subtitle: Text('Erforderlich für die Grundfunktionen der App.'),
                ),
                SwitchListTile(
                  value: analyticsEnabled,
                  onChanged: (val) => setState(() => analyticsEnabled = val),
                  title: const Text('Analytik & Crashlytics'),
                  subtitle: const Text('Hilft uns, Abstürze zu beheben und die App zu verbessern.'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(analyticsEnabled),
                    child: const Text('Speichern'),
                  ),
                ),
              ],
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Check analytics consent stored from a previous session
  const storage = FlutterSecureStorage();
  final consentValue = await storage.read(key: 'analytics_consent');

  // Apply consent to Firebase Analytics (consent banner shown later by InitializerScreen
  // if the key is absent; here we handle already-set values).
  if (consentValue != null) {
    final enabled = consentValue == 'true';
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }

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
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Diplomacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A54A), // Gold / amber for Diplomacy
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          foregroundColor: Color(0xFFE0C97F),
          elevation: 2,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF16213E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4A54A),
            foregroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFF0F3460),
        ),
        useMaterial3: true,
      ),
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
    // Show consent banner on first launch (when analytics_consent key is absent)
    final consentValue = await _storage.read(key: 'analytics_consent');
    if (consentValue == null && mounted) {
      final granted = await _showConsentSheet(context);
      await _storage.write(
        key: 'analytics_consent',
        value: granted ? 'true' : 'false',
      );
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
    }

    final token = await _storage.read(key: 'access_token');
    if (!mounted) return;

    if (token == null) {
      _navigateTo(const LoginScreen());
      return;
    }

    try {
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
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 80,
              color: Color(0xFFD4A54A),
            ),
            SizedBox(height: 24),
            Text(
              'DIPLOMACY',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE0C97F),
                letterSpacing: 8,
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4A54A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
