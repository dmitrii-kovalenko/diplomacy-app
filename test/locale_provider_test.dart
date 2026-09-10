// Regression guard for T23: clearLocale() must drop the persisted
// language_code, not just the in-memory Locale, so a fresh LocaleProvider
// (as created on the next app launch, e.g. after someone else logs in on a
// shared device) does not resurrect the previous account's language.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diplomacy_app/providers/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  // A minimal in-memory stand-in for the platform's secure storage, keyed
  // the same way the real plugin call arguments are, so LocaleProvider's
  // read/write/delete calls behave the same as against a real keystore.
  late Map<String, String> backing;

  setUp(() {
    backing = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      switch (call.method) {
        case 'read':
          return backing[args['key']];
        case 'write':
          backing[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          backing.remove(args['key']);
          return null;
        case 'deleteAll':
          backing.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'clearLocale deletes the persisted language so a fresh provider loads none',
      () async {
    final provider = LocaleProvider();
    await pumpEventQueue();

    provider.setLocale(const Locale('ru'));
    await pumpEventQueue();
    expect(backing['language_code'], 'ru');

    provider.clearLocale();
    await pumpEventQueue();
    expect(provider.locale, isNull);
    expect(backing.containsKey('language_code'), isFalse);

    // Simulate the next login on the same device: a brand new provider
    // must not inherit the language just cleared.
    final fresh = LocaleProvider();
    await pumpEventQueue();
    expect(fresh.locale, isNull);
  });
}
