import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Evita falha de tipo do `firebase_messaging_web` (`.toDart` duplo em `dart2js`).
Future<String> webNotificationPermissionResult() async {
  final dynamic resolved =
      await web.Notification.requestPermission().toDart;
  if (resolved is String) return resolved;
  try {
    return (resolved as JSString).toDart;
  } catch (_) {
    return resolved.toString();
  }
}
