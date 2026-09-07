import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'dummy-api-key',
      appId: '1:1234567890:ios:dummyapp',
      messagingSenderId: '1234567890',
      projectId: 'dummy-project',
    );
  }
}
