import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;
  final _storage = const FlutterSecureStorage();

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  void _loadSavedLocale() async {
    final savedCode = await _storage.read(key: 'language_code');
    if (savedCode != null) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }

  void setLocale(Locale locale) async {
    if (!['en', 'ru', 'uk', 'de', 'cv', 'eo'].contains(locale.languageCode)) return;
    
    _locale = locale;
    await _storage.write(key: 'language_code', value: locale.languageCode);
    notifyListeners();
  }

  void clearLocale() {
    _locale = null;
    notifyListeners();
  }
}
