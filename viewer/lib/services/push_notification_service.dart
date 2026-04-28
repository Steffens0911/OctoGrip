import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// Canal Android (O+); alinhado a `AndroidManifest` meta-data
  /// `com.google.firebase.messaging.default_notification_channel_id`.
  static const String _androidChannelId = 'octogrip_push';
  static const String _androidChannelName = 'Avisos OctoGrip';

  static FlutterLocalNotificationsPlugin? _androidLocalNotifications;
  static void Function(Map<String, String> data)? _notificationOpenHandler;

  /// FCM no Android **não** mostra notificação de sistema com a app em primeiro plano;
  /// usamos notificações locais com o mesmo canal que o FCM usa em segundo plano.
  static Future<void> _ensureAndroidLocalNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_androidLocalNotifications != null) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Avisos da academia e da plataforma.',
        importance: Importance.high,
      ),
    );
    _androidLocalNotifications = plugin;
  }

  static Future<void> _showAndroidForegroundNotification(
      RemoteMessage m) async {
    final n = m.notification;
    final title = (n?.title ?? m.data['title'])?.trim();
    final body = (n?.body ?? m.data['body'])?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    await _ensureAndroidLocalNotifications();
    final plugin = _androidLocalNotifications;
    if (plugin == null) return;
    // Android exige id 32-bit positivo para [show].
    final id = Object.hash(
          m.messageId,
          m.sentTime?.millisecondsSinceEpoch,
          title,
          body,
        ) &
        0x7fffffff;
    await plugin.show(
      id,
      title?.isNotEmpty == true ? title : _androidChannelName,
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Avisos da academia e da plataforma.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

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
        // O [FirebaseMessaging.instance] chama [Firebase.app()] — a app tem de existir primeiro.
        // ignore: avoid_print
        print('[OctoGrip FCM] init web: passo A — Firebase.initializeApp');
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: webOpts);
        }
        var supported = true;
        try {
          // ignore: avoid_print
          print('[OctoGrip FCM] init web: passo B — isSupported');
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
        // ignore: avoid_print
        print('[OctoGrip FCM] init web: passo C — onMessage.listen');
        FirebaseMessaging.onMessage.listen((RemoteMessage m) {
          debugPrint('FCM web foreground: ${m.notification?.title}');
        });
        // ignore: avoid_print
        print('[OctoGrip FCM] init web: passo D — pedido de permissão');
        final perm = await webNotificationPermissionResult();
        if (perm != 'granted') {
          debugPrint(
            'FCM Web: permissão de notificação = $perm (concede no browser para obter token).',
          );
        }
        // ignore: avoid_print
        print('[OctoGrip FCM] init web: passo E — concluído');
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
        if (defaultTargetPlatform == TargetPlatform.android) {
          unawaited(_showAndroidForegroundNotification(m));
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await fm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _ensureAndroidLocalNotifications();
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerTokenQuietly);
      final initialMessage = await fm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpened(initialMessage);
      }
      _firebaseReady = true;
    } catch (e, st) {
      debugPrint('PushNotificationService.init: $e\n$st');
      if (defaultTargetPlatform == TargetPlatform.android) {
        // ignore: avoid_print
        print(
          '[OctoGrip FCM] init Android falhou — confirma google-services.json em '
          'android/app/, o mesmo projectId que firebase_options.dart e Play Services.\n$e',
        );
      }
    }
  }

  static void setNotificationOpenHandler(
      void Function(Map<String, String> data)? handler) {
    _notificationOpenHandler = handler;
  }

  static void _handleNotificationOpened(RemoteMessage m) {
    final data = <String, String>{};
    m.data.forEach((k, v) => data[k] = '$v');
    if (_notificationOpenHandler != null) {
      _notificationOpenHandler!(data);
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
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          // ignore: avoid_print
          print(
            '[OctoGrip FCM] getToken vazio no Android: conceda notificações à app, '
            'confirme google-services.json em android/app/ e o package no Firebase.',
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
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // ignore: avoid_print
        print('[OctoGrip FCM] registerTokenIfLoggedIn (Android): $e');
      }
    }
  }

  /// Re-tenta [registerTokenIfLoggedIn] após o login (Web: SW ainda a registar;
  /// Android/iOS: permissão ou token por vezes só disponível momentos depois).
  static void schedulePostLoginPushTokenRetries() {
    if (!_firebaseReady || !AuthService().isLoggedIn) return;
    final mobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!kIsWeb && !mobile) return;
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
    try {
      await ApiService().deleteAllMyPushTokens();
    } catch (_) {}
    if (!_firebaseReady) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
