// Android: alinhado a `android/app/google-services.json` (projeto octogrip).
// Web FCM: passe `--dart-define=FIREBASE_WEB_APP_ID=1:NUM:web:HASH` (Console Firebase →
// adicionar app Web) e opcionalmente `FCM_VAPID_KEY` (Cloud Messaging → certificados Web Push).
// iOS: registe app no Firebase e execute `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções Firebase (FCM).
class DefaultFirebaseOptions {
  /// `true` quando o build inclui `FIREBASE_WEB_APP_ID` (FCM no browser).
  static bool get webFcmBuildConfigured {
    if (!kIsWeb) return false;
    return const String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '',
    ).trim().isNotEmpty;
  }

  /// Opções para FCM na web; `null` se o build não tiver `FIREBASE_WEB_APP_ID`.
  static FirebaseOptions? get webFcmOptionsOrNull {
    if (!kIsWeb) return null;
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '');
    if (appId.trim().isEmpty) return null;
    return FirebaseOptions(
      apiKey: const String.fromEnvironment(
        'FIREBASE_WEB_API_KEY',
        defaultValue: 'AIzaSyAby3LjFqiQysgqFJF3TDkFyIQbj7XeD2A',
      ),
      appId: appId.trim(),
      messagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '914963189561',
      ),
      projectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: 'octogrip',
      ),
      authDomain: const String.fromEnvironment(
        'FIREBASE_AUTH_DOMAIN',
        defaultValue: 'octogrip.firebaseapp.com',
      ),
      storageBucket: const String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: 'octogrip.firebasestorage.app',
      ),
    );
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      final o = webFcmOptionsOrNull;
      if (o == null) {
        throw UnsupportedError(
          'FCM Web: defina FIREBASE_WEB_APP_ID com --dart-define no flutter build.',
        );
      }
      return o;
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
