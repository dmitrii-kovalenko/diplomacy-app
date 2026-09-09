import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyB1QpyvBN157VrsORYErLOVqz2roWIfGY8',
        appId: '1:646660581815:android:895cc9d8ca75b8172be032',
        messagingSenderId: '646660581815',
        projectId: 'hegemony-game',
      );
    }
    return const FirebaseOptions(
      apiKey: 'dummy-api-key',
      appId: '1:1234567890:ios:dummyapp',
      messagingSenderId: '1234567890',
      projectId: 'dummy-project',
    );
  }
}
