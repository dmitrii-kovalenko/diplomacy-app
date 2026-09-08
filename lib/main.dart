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
import 'package:google_fonts/google_fonts.dart';

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
                Text(
                  'Datenschutz-Einstellungen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
    
    // Diplomacy Design System Colors
    const colorBackground = Color(0xFF0F1526);
    const colorSurface = Color(0xFF1D2342);
    // ignore: unused_local_variable
    const colorSurfaceRaised = Color(0xFF242E4F);
    const colorAccent = Color(0xFF5AC397);
    const colorGold = Color(0xFFF0D36C);
    const colorDanger = Color(0xFFE0685F);

    final baseTextTheme = GoogleFonts.ibmPlexSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    final displayFont = GoogleFonts.fraunces();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Diplomacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: colorAccent,
          secondary: colorGold,
          surface: colorSurface,
          error: colorDanger,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: colorBackground,
        textTheme: baseTextTheme.copyWith(
          displayLarge: baseTextTheme.displayLarge?.merge(displayFont),
          displayMedium: baseTextTheme.displayMedium?.merge(displayFont),
          displaySmall: baseTextTheme.displaySmall?.merge(displayFont),
          headlineLarge: baseTextTheme.headlineLarge?.merge(displayFont),
          headlineMedium: baseTextTheme.headlineMedium?.merge(displayFont),
          headlineSmall: baseTextTheme.headlineSmall?.merge(displayFont),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: colorBackground,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: colorSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Colors.white12, width: 1), // Hairline border
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: colorAccent),
          ),
          filled: true,
          fillColor: colorSurface,
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 24),
            Text(
              'DIPLOMACY',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
