// Firebase configuration for the Match Chat app.
//
// Values come from the `tiago-dev-site` Firebase project (see docs/firebase.md).
// Only the web platform is configured because Match Chat is a Flutter Web app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Match Chat targets Flutter Web only. Configure other platforms '
          'with `flutterfire configure` if you add them later.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAOJCxd1PY7JcsIc2z1KtCVZcDst4CtnFM',
    authDomain: 'tiago-dev-site.firebaseapp.com',
    projectId: 'tiago-dev-site',
    storageBucket: 'tiago-dev-site.firebasestorage.app',
    messagingSenderId: '706177559293',
    appId: '1:706177559293:web:0e098fd3c81ad705d7ac94',
  );
}
