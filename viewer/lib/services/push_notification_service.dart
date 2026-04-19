import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:viewer/firebase_options.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/push_notification_web_permission_stub.dart'
    if (dart.library.js_interop) 'package:viewer/services/push_notification_web_permission.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  final options = defaultTargetPlatform == TargetPlatform.iOS
      ? DefaultFirebaseOptions.ios
      : DefaultFirebaseOptions.android;
  await Firebase.initializeApp(options: options);
}

/// Inicializa FCM (Android / iOS / Web com build configurado), regista token na API após login.
///
/// **Web:** só activa se o build incluir `FIREBASE_WEB_APP_ID` e existir
/// `web/firebase-messaging-sw.js` coerente (ver `docs/PUSH_NOTIFICATIONS.md`).
/// No servidor: `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT_PATH`.
class PushNotificationService {
  PushNotificationService._();
  static bool _firebaseReady = false;

  static const String _vapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue: '',
  );

  static Future<void> init() async {
    if (_firebaseReady) return;

    if (kIsWeb) {
      final webOpts = DefaultFirebaseOptions.webFcmOptionsOrNull;
      if (webOpts == null) {
        debugPrint(
          'FCM Web: desativado neste build (defina --dart-define=FIREBASE_WEB_APP_ID=...).',
        );
        // ignore: avoid_print
        print(
          '[OctoGrip FCM] Web desativado: FIREBASE_WEB_APP_ID ausente no build Dart. '
          'O firebase-messaging-sw.js pode estar certo, mas o Flutter precisa do mesmo define.',
        );
        return;
      }
      try {
        var supported = true;
        try {
          supported = await FirebaseMessaging.instance.isSupported();
        } catch (e, st) {
          debugPrint(
            'FCM Web: isSupported falhou (continuação assumindo suportado): $e\n$st',
          );
        }
        if (!supported) {
          debugPrint('FCM Web: este browser não suporta Firebase Messaging.');
          return;
        }
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: webOpts);
        }
        FirebaseMessaging.onMessage.listen((RemoteMessage m) {
          debugPrint('FCM web foreground: ${m.notification?.title}');
        });
        final perm = await webNotificationPermissionResult();
        if (perm != 'granted') {
          debugPrint(
            'FCM Web: permissão de notificação = $perm (concede no browser para obter token).',
          );
        }
        FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenQuietly);
        _firebaseReady = true;
      } catch (e, st) {
        debugPrint('PushNotificationService.init (web): $e\n$st');
        // ignore: avoid_print
        print(
          '[OctoGrip FCM] init (web) falhou — copia erro + stack completos:\n'
          '$e\n'
          '$st',
        );
      }
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
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
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenQuietly);
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

  static Future<String?> _fcmToken() async {
    final v = _vapidKey.trim();
    if (kIsWeb && v.isNotEmpty) {
      return FirebaseMessaging.instance.getToken(vapidKey: v);
    }
    return FirebaseMessaging.instance.getToken();
  }

  /// Chamar após login (ou ao iniciar com sessão já salva).
  static Future<void> registerTokenIfLoggedIn() async {
    if (!_firebaseReady || !AuthService().isLoggedIn) return;
    try {
      final token = await _fcmToken();
      if (token == null || token.isEmpty) {
        if (kIsWeb) {
          // Consola do browser (release): ajuda a diagnosticar SW/VAPID/permissões.
          // ignore: avoid_print
          print(
            '[OctoGrip FCM] getToken devolveu vazio. Permissões de notificação, '
            'FCM_VAPID_KEY no build e firebase-messaging-sw.js com o mesmo appId.',
          );
        }
        return;
      }
      await ApiService().registerMyPushToken(token, _platformLabel());
    } catch (e, st) {
      debugPrint('registerTokenIfLoggedIn: $e\n$st');
      if (kIsWeb) {
        // ignore: avoid_print
        print('[OctoGrip FCM] registerTokenIfLoggedIn: $e');
      }
    }
  }

  /// Na Web o [firebase_messaging] pode falhar na 1.ª tentativa (service worker
  /// ainda a registar). Re-tenta em segundo plano sem bloquear a UI.
  static void scheduleWebPushTokenRetries() {
    if (!kIsWeb || !_firebaseReady) return;
    Future<void>(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (AuthService().isLoggedIn) await registerTokenIfLoggedIn();
      await Future<void>.delayed(const Duration(seconds: 5));
      if (AuthService().isLoggedIn) await registerTokenIfLoggedIn();
    });
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
