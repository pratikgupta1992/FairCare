/// Firebase configuration drop point.
///
/// ⚠️ PLACEHOLDER VALUES — this file exists so the project compiles,
/// analyzes, and tests BEFORE the real Firebase project config
/// exists. It contains NO real credentials.
///
/// Replace the whole file by running, from `mobile/`:
///
///     flutterfire configure
///
/// (with the Firebase CLI installed and signed in to the Google
/// account that owns the FairCare Firebase project). Or paste the
/// values from Firebase Console → Project settings → Your apps.
/// Nothing else in the codebase needs to change when the real
/// values land — `main.dart` reads only this class.
///
/// On Android, `flutterfire configure` also drops
/// `android/app/google-services.json`; on iOS it drops
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

  // REPLACE via `flutterfire configure` — placeholder values below.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );

  // REPLACE via `flutterfire configure` — placeholder values below.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
    iosBundleId: 'com.faircare.faircare',
  );
}
