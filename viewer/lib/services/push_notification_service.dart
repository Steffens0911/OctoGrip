import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:viewer/firebase_options.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Inicializa FCM (Android/iOS), regista token na API após login.
///
/// Requer `firebase_options.dart` com projeto real e, no servidor,
/// `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT_PATH` para o gerente enviar avisos.
class PushNotificationService {
  PushNotificationService._();
  static bool _firebaseReady = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (_firebaseReady) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage m) {
        debugPrint('FCM foreground: ${m.notification?.title}');
      });
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _registerTokenQuietly(t);
      });
      _firebaseReady = true;
    } catch (e, st) {
      debugPrint('PushNotificationService.init: $e\n$st');
    }
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  /// Chamar após login (ou ao arrancar com sessão já guardada).
  static Future<void> registerTokenIfLoggedIn() async {
    if (!_firebaseReady || !AuthService().isLoggedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService().registerMyPushToken(token, _platformLabel());
    } catch (e) {
      debugPrint('registerTokenIfLoggedIn: $e');
    }
  }

  static Future<void> _registerTokenQuietly(String token) async {
    if (!AuthService().isLoggedIn) return;
    try {
      await ApiService().registerMyPushToken(token, _platformLabel());
    } catch (_) {}
  }

  /// Chamado no logout: remove tokens no servidor e invalida FCM local.
  static Future<void> unregister() async {
    if (!_firebaseReady) return;
    try {
      await ApiService().deleteAllMyPushTokens();
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
