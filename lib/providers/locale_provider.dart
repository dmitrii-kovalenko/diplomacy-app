import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  final _storage = const FlutterSecureStorage();

  // Sourced from the generated delegate rather than hardcoded, so the
  // accepted set can never drift from the ARB files that actually ship.
  static final Set<String> _supportedCodes = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  void _loadSavedLocale() async {
    final savedCode = await _storage.read(key: 'language_code');
    // A code saved by an older build (or an ARB file removed since) must not
    // brick startup — fall back to the device default instead of rendering
    // a locale we no longer ship.
    if (savedCode != null && _supportedCodes.contains(savedCode)) {
      _locale = Locale(savedCode);
      notifyListeners();
    } else if (savedCode != null) {
      // The stored code is no longer one we ship (an ARB was removed since
      // it was saved) — clear it so it does not linger in secure storage
      // forever, since we are already falling back to the device default.
      await _storage.delete(key: 'language_code');
    }
  }

  void setLocale(Locale locale) async {
    if (!_supportedCodes.contains(locale.languageCode)) return;

    _locale = locale;
    await _storage.write(key: 'language_code', value: locale.languageCode);
    notifyListeners();
  }

  void clearLocale() {
    _locale = null;
    notifyListeners();
  }
}
