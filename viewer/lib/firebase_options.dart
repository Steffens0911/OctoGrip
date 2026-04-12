// Android: alinhado a `android/app/google-services.json` (projeto octogrip).
// Web/iOS: registe apps no Firebase e execute `flutterfire configure` ou complete os placeholders.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções Firebase (FCM).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: plataforma não suportada para FCM.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'octogrip-placeholder',
    authDomain: 'octogrip-placeholder.firebaseapp.com',
    storageBucket: 'octogrip-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAby3LjFqiQysgqFJF3TDkFyIQbj7XeD2A',
    appId: '1:914963189561:android:56e0d6283d64fa3c4fe2e8',
    messagingSenderId: '914963189561',
    projectId: 'octogrip',
    storageBucket: 'octogrip.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'octogrip-placeholder',
    storageBucket: 'octogrip-placeholder.appspot.com',
    iosBundleId: 'com.example.viewer',
  );
}
