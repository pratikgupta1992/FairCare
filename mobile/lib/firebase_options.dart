/// Firebase configuration drop point.
///
/// Android and iOS hold the REAL values for Firebase project
/// `faircare-9c88f` (wired 2026-10-21 from the config files the
/// project owner downloaded from the Firebase Console). The web
/// options remain placeholders — web is not a configured platform.
///
/// Nothing else in the codebase reads Firebase values directly —
/// `main.dart` reads only this class.
///
/// The matching platform files are also in place:
/// `android/app/google-services.json` and
/// `ios/Runner/GoogleService-Info.plist`. Both are required for a
/// real device run; neither is needed for analyze/test.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android/iOS. '
          'Run `flutterfire configure` to add this platform.',
        );
    }
  }

  // REPLACE via `flutterfire configure` — placeholder values below.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
    authDomain: 'REPLACE_ME',
  );

  // Real values — Firebase project faircare-9c88f (2026-10-21),
  // sourced from the user's google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA6vlvNhStFvZyQCo5YpFsP-Vha-14AA7Q',
    appId: '1:414814305942:android:258d045731c5ca46530cb7',
    messagingSenderId: '414814305942',
    projectId: 'faircare-9c88f',
    storageBucket: 'faircare-9c88f.firebasestorage.app',
  );

  // Real values — Firebase project faircare-9c88f (2026-10-21),
  // sourced from the user's GoogleService-Info.plist.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDzWm5sO0ws17sA7ghFnoTCCwISwL9Q18U',
    appId: '1:414814305942:ios:d8e56fbbd52d6017530cb7',
    messagingSenderId: '414814305942',
    projectId: 'faircare-9c88f',
    storageBucket: 'faircare-9c88f.firebasestorage.app',
    iosBundleId: 'com.faircare.faircare',
  );
}
