import 'dart:async';
import 'dart:convert';

import 'package:viewer/config.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Evento emitido pelo WebSocket `/attendance/sessions/{id}/ws`.
sealed class AttendanceLiveEvent {}

/// Novo check-in na sessão (aluno registrou presença).
class AttendanceCheckinLiveEvent extends AttendanceLiveEvent {
  final AttendanceRecordModel record;
  final int presentCount;

  AttendanceCheckinLiveEvent({
    required this.record,
    required this.presentCount,
  });
}

/// Presença removida (professor/gestor corrigiu a lista).
class AttendanceRecordRemovedLiveEvent extends AttendanceLiveEvent {
  final String sessionId;
  final String recordId;
  final String userId;
  final int presentCount;

  AttendanceRecordRemovedLiveEvent({
    required this.sessionId,
    required this.recordId,
    required this.userId,
    required this.presentCount,
  });
}

/// Conexão WebSocket com reconexão exponencial (1s → 30s máx).
///
/// Use [connect] ao abrir a sessão e [dispose] em [dispose] da tela ou ao encerrar a chamada.
class AttendanceLiveService {
  final StreamController<AttendanceLiveEvent> _controller =
      StreamController<AttendanceLiveEvent>.broadcast();

  StreamSubscription<dynamic>? _sub;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _sessionId;
  bool _disposed = false;
  int _backoffMs = 1000;
  static const int _maxBackoffMs = 30000;

  /// Eventos parseados do servidor.
  Stream<AttendanceLiveEvent> get stream => _controller.stream;

  /// Inicia ou reinicia a ligação para [sessionId] (cancela socket anterior).
  void connect(String sessionId) {
    _disposed = false;
    _sessionId = sessionId;
    _backoffMs = 1000;
    _stopSocketOnly();
    unawaited(_openSocket());
  }

  Uri _buildWsUri(String sessionId, String token) {
    final base = Uri.parse(kApiBaseUrl.replaceFirst(RegExp(r'/$'), ''));
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final pathPrefix = base.path.isEmpty || base.path == '/'
        ? ''
        : base.path.endsWith('/')
            ? base.path.substring(0, base.path.length - 1)
            : base.path;
    final path = pathPrefix.isEmpty
        ? '/attendance/sessions/$sessionId/ws'
        : '$pathPrefix/attendance/sessions/$sessionId/ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: {'token': token},
    );
  }

  Future<void> _openSocket() async {
    if (_disposed || _sessionId == null) return;
    await AuthService().ensureLoaded();
    final token = AuthService().token;
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final uri = _buildWsUri(_sessionId!, token);
    try {
      _stopSocketOnly();
      final ch = WebSocketChannel.connect(uri);
      _channel = ch;
      await ch.ready;
      _backoffMs = 1000;
      _sub = ch.stream.listen(
        (dynamic data) {
          if (_disposed) return;
          final text = data is String ? data : utf8.decode(data as List<int>);
          _handleMessage(text);
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(String text) {
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (!_controller.isClosed) {
        if (type == 'checkin') {
          final rec = map['record'];
          if (rec is! Map<String, dynamic>) return;
          final count = (map['present_count'] as num?)?.toInt() ?? 0;
          _controller.add(
            AttendanceCheckinLiveEvent(
              record: AttendanceRecordModel.fromJson(rec),
              presentCount: count,
            ),
          );
        } else if (type == 'record_removed') {
          final sid = map['session_id'] as String?;
          final rid = map['record_id'] as String?;
          final uid = map['user_id'] as String?;
          if (sid == null || rid == null || uid == null) return;
          final count = (map['present_count'] as num?)?.toInt() ?? 0;
          _controller.add(
            AttendanceRecordRemovedLiveEvent(
              sessionId: sid,
              recordId: rid,
              userId: uid,
              presentCount: count,
            ),
          );
        }
      }
    } catch (_) {
      // payload inválido — ignora
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _sessionId == null) return;
    _stopSocketOnly();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), () {
      if (_disposed) return;
      _backoffMs = (_backoffMs * 2).clamp(1000, _maxBackoffMs);
      unawaited(_openSocket());
    });
  }

  void _stopSocketOnly() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final oldSub = _sub;
    _sub = null;
    oldSub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Fecha socket, timers e o stream de eventos.
  void dispose() {
    _disposed = true;
    _sessionId = null;
    _stopSocketOnly();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
