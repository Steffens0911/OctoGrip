import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:viewer/config.dart';
import 'package:viewer/constants/reward_points.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/models/academy_student_list_item.dart';
import 'package:viewer/models/active_students_report.dart';
import 'package:viewer/models/engagement_report.dart';
import 'package:viewer/models/face_checkin.dart';
import 'package:viewer/models/face_recognition.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/models/professor.dart';
import 'package:viewer/models/professor_impact.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/models/mission_completion_report.dart';
import 'package:viewer/models/students_attention_report.dart';
import 'package:viewer/models/user_academy_stats.dart';
import 'package:viewer/models/technique_execution_summary.dart';
import 'package:viewer/models/weekly_panel_login_report.dart';
import 'package:viewer/models/attendance.dart';
import 'package:viewer/models/attendance_qr.dart';
import 'package:viewer/models/attendance_ranking.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/models/weekly_kit.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/services/backup_multipart_io.dart'
    if (dart.library.html) 'package:viewer/services/backup_multipart_web.dart'
    as backup_multipart;

dynamic _decodeJsonInIsolate(String body) => jsonDecode(body);

String _encodeJsonInIsolate(Object payload) => jsonEncode(payload);

class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Tipo da exceção no payload `error.type` (ex.: `AccountFrozenError`).
  final String? errorType;
  ApiException(this.statusCode, this.message, {this.errorType});
  @override
  String toString() => message;
}

/// Cache in-memory com TTL para reduzir requisições repetidas (troca de telas, abas).
///
/// Stale-while-revalidate: até [staleAtMs] serve direto; entre [staleAtMs] e
/// [expiresAtMs] serve o cache imediatamente e revalida em background — telas
/// nunca voltam a mostrar spinner se já têm dado conhecido.
class _CacheEntry {
  final String body;
  final int statusCode;
  final int staleAtMs;
  final int expiresAtMs;
  _CacheEntry(this.body, this.statusCode, this.staleAtMs, this.expiresAtMs);
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  /// Lida sempre com [kApiBaseUrl] para `?api_base=` / sessionStorage surtirem efeito sem reload rígido.
  String get baseUrl => kApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  static const _timeout = Duration(seconds: 30);
  static const _getTimeout = Duration(seconds: 15);

  /// Cliente HTTP — substituível em testes via [setHttpClientForTesting].
  http.Client _client = http.Client();

  @visibleForTesting
  void setHttpClientForTesting(http.Client client) => _client = client;

  final Map<String, _CacheEntry> _getCache = {};
  static const int _cacheTtlShort =
      45; // mission_today, week, pending count (pull-to-refresh pode servir cache válido)
  static const int _cacheTtlMedium =
      60; // listas: academies, lessons, techniques, users
  static const int _cacheTtlHeader = 45; // snapshot do header da home

  /// Evita vários GET simultâneos ao mesmo endpoint (reduz pressão no browser / ERR_INSUFFICIENT_RESOURCES).
  Future<List<TrainingVideo>>? _inFlightTrainingVideosToday;

  ApiService._();

  String _cacheKey(String method, Uri uri) => '$method:${uri.toString()}';

  /// Janela máxima do stale-while-revalidate: depois do TTL "fresco" o dado
  /// ainda é servido (com revalidação em background) por até este tempo.
  static const int _cacheHardTtlSeconds = 600;

  _CacheEntry? _validEntry(String key) {
    final entry = _getCache[key];
    if (entry == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > entry.expiresAtMs) {
      _getCache.remove(key);
      return null;
    }
    return entry;
  }

  void _setCache(String key, String body, int statusCode, int ttlSeconds) {
    if (statusCode < 200 || statusCode >= 300) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hardTtl = ttlSeconds > _cacheHardTtlSeconds
        ? ttlSeconds
        : _cacheHardTtlSeconds;
    _getCache[key] = _CacheEntry(
      body,
      statusCode,
      nowMs + (ttlSeconds * 1000),
      nowMs + (hardTtl * 1000),
    );
  }

  /// Invalida cache por prefixo (ex: "GET:$baseUrl/academies") ou todo o cache.
  void invalidateCache([String? prefix]) {
    if (prefix == null || prefix.isEmpty) {
      _getCache.clear();
      _usersAllCache.clear();
      return;
    }
    _getCache.removeWhere((k, _) => k.startsWith(prefix));
    if (prefix.startsWith('GET:$baseUrl/users')) {
      _usersAllCache.clear();
    }
  }

  void _invalidateHomeHeaderCache() {
    invalidateCache('GET:$baseUrl/me/header_stats');
  }

  void _invalidateAttendanceCache() {
    invalidateCache('GET:$baseUrl/attendance');
  }

  Future<http.Response> _req(
    Future<http.Response> f, {
    Duration? timeout,
  }) =>
      f.timeout(
        timeout ?? _timeout,
        onTimeout: () {
          throw TimeoutException(
            'Tempo esgotado ao chamar a API. Verifique conectividade da API e tente novamente.',
          );
        },
      );

  /// Deduplica GETs simultâneos ao mesmo endpoint e as revalidações em background.
  final Map<String, Future<http.Response>> _inFlightGets = {};

  /// GET com cache. [ttlSeconds] 0 = sem cache. Dentro do TTL serve direto;
  /// entre o TTL e [_cacheHardTtlSeconds] serve o cache imediatamente e
  /// revalida em background (stale-while-revalidate).
  Future<http.Response> _getWithCache(Uri uri, int ttlSeconds) async {
    final key = _cacheKey('GET', uri);
    if (ttlSeconds > 0) {
      final entry = _validEntry(key);
      if (entry != null && entry.statusCode >= 200 && entry.statusCode < 300) {
        if (DateTime.now().millisecondsSinceEpoch > entry.staleAtMs) {
          unawaited(
            _fetchAndCache(uri, key, ttlSeconds).then((_) {}, onError: (_) {}),
          );
        }
        return http.Response(entry.body, 200,
            headers: {'content-type': 'application/json'});
      }
    }
    return _fetchAndCache(uri, key, ttlSeconds);
  }

  Future<http.Response> _fetchAndCache(Uri uri, String key, int ttlSeconds) {
    final inFlight = _inFlightGets[key];
    if (inFlight != null) return inFlight;
    final future = () async {
      try {
        final r = await _req(
          _client.get(uri, headers: await _headers(auth: true)),
          timeout: _getTimeout,
        );
        if (ttlSeconds > 0 && r.statusCode >= 200 && r.statusCode < 300) {
          _setCache(key, r.body, r.statusCode, ttlSeconds);
        }
        return r;
      } finally {
        _inFlightGets.remove(key);
      }
    }();
    _inFlightGets[key] = future;
    return future;
  }

  /// Garante que o token foi carregado do storage (importante no web após refresh).
  Future<void> _ensureAuth() async => await AuthService().ensureLoaded();

  /// [realUserOnly] true = não envia X-Impersonate-User (para o admin conseguir listar usuários e voltar da simulação).
  Future<Map<String, String>> _headers(
      {bool auth = false, bool realUserOnly = false}) async {
    if (auth) await _ensureAuth();
    final h = <String, String>{};
    if (auth) {
      final bearer = AuthService().authHeader;
      if (bearer != null) h['Authorization'] = bearer;
      if (!realUserOnly) {
        final impersonate = AuthService().impersonatedUserId;
        if (impersonate != null) h['X-Impersonate-User'] = impersonate;
      }
    }
    return h;
  }

  Future<Map<String, String>> _jsonHeaders(
      {bool auth = false, bool realUserOnly = false}) async {
    final h = await _headers(auth: auth, realUserOnly: realUserOnly);
    h['Content-Type'] = 'application/json';
    return h;
  }

  // ---------- Auth ----------
  /// Login. Retorna (token, user, streakBonusPoints). Lança ApiException em erro.
  Future<({String token, UserModel user, int streakBonusPoints})> login(
    String email,
    String password,
  ) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    ));
    final data = await _decodeResponse(r);
    // noAutoLogout=true: falha no login (ex.: senha errada → 401) nunca deve
    // disparar logout automático — o utilizador pode ter um token antigo guardado
    // e isLoggedIn ficaria true, causando logout + loop de push_tokens DELETE.
    _throwIfNotOk(r, data, true);
    final map = data! as Map<String, dynamic>;
    final token = map['access_token'] as String;
    final streakBonusPoints = map['streak_bonus_points'] as int? ?? 0;
    final user = await getAuthMe(token);
    return (token: token, user: user, streakBonusPoints: streakBonusPoints);
  }

  /// Check-in diário silencioso. Retorna pontos de streak concedidos (0 se nenhum).
  /// Idempotente — pode ser chamado várias vezes no mesmo dia sem efeito colateral.
  Future<int> postDailyCheckin() async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/auth/daily-checkin'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    // noAutoLogout=true: o caller (DailyCheckinService) já trata erros silenciosamente;
    // um 401 aqui não deve disparar logout — o MainShell detetará tokens expirados.
    _throwIfNotOk(r, data, true);
    final map = data! as Map<String, dynamic>;
    return map['streak_bonus_points'] as int? ?? 0;
  }

  /// Solicita link de recuperação de senha. Sempre retorna 200 (anti-enumeração).
  Future<void> forgotPassword(String email) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'email': email}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data, true);
  }

  /// Redefine a senha usando o token recebido por e-mail.
  Future<void> resetPassword(String token, String newPassword) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data, true);
  }

  /// Retorna o usuário logado (requer token).
  Future<UserModel> getAuthMe([String? token]) async {
    final h = token != null
        ? <String, String>{'Authorization': 'Bearer $token'}
        : await _jsonHeaders(auth: true);
    final r = await _req(_client.get(Uri.parse('$baseUrl/auth/me'), headers: h));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  /// [GET /auth/me] **sem** `X-Impersonate-User`: conta que assina o JWT (admin real durante «Atuar como»).
  Future<UserModel> getAuthMeAsRealUser() async {
    final h = await _jsonHeaders(auth: true, realUserOnly: true);
    final r = await _req(_client.get(Uri.parse('$baseUrl/auth/me'), headers: h));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza preferência "galeria visível para outros" do usuário autenticado.
  Future<UserModel> patchMeGalleryVisible(bool visible) async {
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'gallery_visible': visible}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateHomeHeaderCache();
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  /// Registra token FCM para o usuário autenticado (Android/iOS).
  Future<void> registerMyPushToken(String token, String platform) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/me/push_token'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'token': token, 'platform': platform}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  /// Remove todos os tokens FCM do usuário (logout).
  /// Usa noAutoLogout=true: um 401 aqui (JWT já expirado) não deve
  /// disparar novo logout — o chamador (PushNotificationService.unregister)
  /// já faz parte do fluxo de logout e captura erros silenciosamente.
  Future<void> deleteAllMyPushTokens() async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/me/push_tokens'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data, true);
  }

  /// Envia notificação push a usuários da academia com app e tokens registrados.
  Future<({int targetTokens, int sent, int failed})>
      sendAcademyPushNotification(
    String academyId, {
    required String title,
    required String body,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/push_notification'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'title': title, 'body': body}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final m = data! as Map<String, dynamic>;
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return (
      targetTokens: n(m['target_tokens']),
      sent: n(m['sent']),
      failed: n(m['failed']),
    );
  }

  /// Broadcast push a todos os tokens FCM (apenas administrador global).
  Future<({int targetTokens, int sent, int failed})> sendAdminPushBroadcast({
    required String title,
    required String body,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/admin/push_broadcast'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'title': title, 'body': body}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final m = data! as Map<String, dynamic>;
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return (
      targetTokens: n(m['target_tokens']),
      sent: n(m['sent']),
      failed: n(m['failed']),
    );
  }

  Future<TrainingStats> getTrainingStats() async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/me/training_stats'),
      _cacheTtlShort,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return TrainingStats.fromJson(data as Map<String, dynamic>);
  }

  /// Snapshot agregado do header/home do usuário atual.
  /// Inclui nível persistido, XP no nível e configurações visuais da academia.
  Future<Map<String, dynamic>> getMeHeaderStats() async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/me/header_stats'),
      _cacheTtlHeader,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<dynamic> _decodeJsonPayload(String body) async {
    if (body.length < 12000) {
      return jsonDecode(body);
    }
    try {
      return await compute(_decodeJsonInIsolate, body);
    } catch (_) {
      return jsonDecode(body);
    }
  }

  Future<String> _encodeJsonPayload(Object payload) async {
    try {
      return await compute(_encodeJsonInIsolate, payload);
    } catch (_) {
      return jsonEncode(payload);
    }
  }

  Future<dynamic> _decodeResponse(http.Response r) async {
    final body = r.body;
    if (body.isEmpty) return null;
    try {
      return await _decodeJsonPayload(body);
    } catch (_) {
      // Resposta não-JSON (proxy, HTML); _throwIfNotOk usa statusCode + reasonPhrase
      return null;
    }
  }

  /// Formata `detail` do FastAPI (string, lista de erros de validação, etc.).
  static String formatApiDetail(dynamic detail) {
    if (detail == null) return '';
    if (detail is String) return detail;
    if (detail is List) {
      final raw = detail.toString();
      // API antiga ainda exige posições removidas no schema atual do repositório.
      if (raw.contains('from_position_id') || raw.contains('to_position_id')) {
        return 'A API que está rodando está desatualizada: ela ainda exige '
            '"from_position_id" e "to_position_id", que foram removidos do modelo de técnicas. '
            'Reconstrua e suba o serviço da API com o código atual e aplique as migrações '
            '(inclui migrations/044_remove_technique_positions.sql). '
            'Ex.: na pasta do projeto: docker compose build --no-cache api && docker compose up -d api';
      }
      final msgs = <String>[];
      for (final e in detail) {
        if (e is Map && e['msg'] != null) {
          final loc = e['loc'];
          final locStr = loc is List ? loc.join('.') : '$loc';
          msgs.add('$locStr: ${e['msg']}');
        }
      }
      if (msgs.isNotEmpty) return msgs.join('\n');
    }
    return detail.toString();
  }

  void _throwIfNotOk(
    http.Response r, [
    dynamic data,
    bool noAutoLogout = false,
  ]) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    // Só faz logout automático se havia uma sessão ativa (token presente) e
    // o chamador não optou por suprimir (ex.: deleteAllMyPushTokens, que faz
    // parte do próprio fluxo de logout — chamar logout aqui causaria loop).
    if (r.statusCode == 401 && !noAutoLogout && AuthService().isLoggedIn) {
      unawaited(AuthService().logout(notifyInvalidated: true));
    }
    String msg = r.reasonPhrase ?? 'Erro ${r.statusCode}';
    String? errorType;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['type'] != null) {
        errorType = err['type'] as String?;
      }
      if (data['detail'] != null) {
        msg = formatApiDetail(data['detail']);
      } else {
        if (err is Map && err['message'] != null) {
          msg = '${err['message']}';
        }
      }
    }
    if (r.statusCode == 404) {
      // Só sobrescreve a mensagem se não vier um detalhe específico da API
      if (msg.isEmpty || msg == 'Not Found') {
        msg = 'Recurso não encontrado (404).';
      }
    }
    throw ApiException(r.statusCode, msg, errorType: errorType);
  }

  // ---------- Academies ----------
  /// [asRealUser] true = não envia X-Impersonate-User (lista completa para o seletor "Atuar como" mesmo durante simulação).
  Future<List<Academy>> getAcademies({bool asRealUser = false}) async {
    final uri = Uri.parse('$baseUrl/academies');
    final r = asRealUser
        ? await _req(_client.get(uri,
            headers: await _headers(auth: true, realUserOnly: true)))
        : await _getWithCache(uri, _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Academy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Academy> getAcademy(String id) async {
    final r = await _getWithCache(
        Uri.parse('$baseUrl/academies/$id'), _cacheTtlMedium);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Retorna a academia sem usar cache (para o brasão na home do aluno aparecer logo após o admin salvar).
  ///
  /// Em 403, chama `AuthService().refreshMe()` e tenta de novo com o `academy_id` atual do servidor
  /// (evita brasão vazio quando o usuário em cache ficou desatualizado).
  Future<Academy> getAcademyFresh(String id) async {
    Future<Academy> fetchOnce(String academyId) async {
      final r = await _req(_client.get(
        Uri.parse('$baseUrl/academies/$academyId'),
        headers: await _headers(auth: true),
      ));
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
      return Academy.fromJson(data! as Map<String, dynamic>);
    }

    try {
      return await fetchOnce(id);
    } on ApiException catch (e) {
      if (e.statusCode != 403) rethrow;
      try {
        await AuthService().refreshMe();
      } catch (_) {
        rethrow;
      }
      final fresh = AuthService().currentUser?.academyId?.trim();
      if (fresh != null && fresh.isNotEmpty && fresh != id) {
        invalidateCache('GET:$baseUrl/academies');
        return await fetchOnce(fresh);
      }
      // Fallback adicional: em alguns cenários (token/impersonação recém-trocados),
      // o id em memória pode não bater; usa a academia visível para o usuário atual.
      try {
        final mine = await getAcademies();
        if (mine.isNotEmpty) {
          return mine.first;
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Resolve URL de horários: se for post do Instagram, retorna thumbnail para exibição; senão retorna a própria URL.
  /// Retorna { display_url: String?, original_url: String? }.
  Future<Map<String, dynamic>> getScheduleDisplayUrl(String scheduleUrl) async {
    final uri = Uri.parse('$baseUrl/academies/schedule_display_url').replace(
      queryParameters: {'url': scheduleUrl},
    );
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return {
      'display_url': map['display_url'] as String?,
      'original_url': map['original_url'] as String?,
    };
  }

  Future<Map<String, dynamic>?> getCollectiveGoalCurrent(
      String academyId) async {
    Future<Map<String, dynamic>?> fetchOnce(String id) async {
      final r = await _getWithCache(
        Uri.parse('$baseUrl/academies/$id/collective_goals/current'),
        _cacheTtlShort,
      );
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
      if (data == null) return null;
      return data as Map<String, dynamic>;
    }

    try {
      return await fetchOnce(academyId);
    } on ApiException catch (e) {
      if (e.statusCode != 403) rethrow;
      try {
        await AuthService().refreshMe();
      } catch (_) {
        rethrow;
      }
      final fresh = AuthService().currentUser?.academyId?.trim();
      if (fresh != null && fresh.isNotEmpty && fresh != academyId) {
        return await fetchOnce(fresh);
      }
      rethrow;
    }
  }

  Future<Academy> createAcademy({required String name, String? slug}) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'name': name, 'slug': slug}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy> updateAcademyTheme(String id, String? weeklyTheme) async {
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'weekly_theme': weeklyTheme}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  static const _pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const _jpegMagic = [0xFF, 0xD8];
  static const _webpMagic = [0x52, 0x49, 0x46, 0x46]; // RIFF
  static const _webpFourcc = [0x57, 0x45, 0x42, 0x50]; // WEBP at 8:12

  static MediaType? _contentTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return null;
    }
  }

  static String _extensionFromBytes(Uint8List bytes) {
    if (bytes.length >= 8) {
      bool match(List<int> magic, int offset) {
        for (var i = 0; i < magic.length; i++) {
          if (offset + i >= bytes.length ||
              (bytes[offset + i] & 0xff) != magic[i]) return false;
        }
        return true;
      }

      if (match(_pngMagic, 0)) return 'png';
      if (bytes.length >= 2 && match(_jpegMagic, 0)) return 'jpg';
      if (bytes.length >= 12 && match(_webpMagic, 0) && match(_webpFourcc, 8))
        return 'webp';
    }
    return 'png';
  }

  static MediaType _mediaTypeFromContentTypeOrFilename(
    String? contentType,
    String filename,
    Uint8List bytes,
  ) {
    final normalized = (contentType ?? '').toLowerCase();
    if (normalized.contains('png')) return MediaType('image', 'png');
    if (normalized.contains('webp')) return MediaType('image', 'webp');
    if (normalized.contains('jpeg') || normalized.contains('jpg')) {
      return MediaType('image', 'jpeg');
    }
    final fromName = _contentTypeFromFilename(filename);
    if (fromName != null) return fromName;
    final ext = _extensionFromBytes(bytes);
    if (ext == 'webp') return MediaType('image', 'webp');
    if (ext == 'jpg') return MediaType('image', 'jpeg');
    return MediaType('image', 'png');
  }

  Future<Academy> uploadAcademyLogo(
      String id, Uint8List bytes, String filename) async {
    var name = filename;
    var contentType = _contentTypeFromFilename(filename);
    if (contentType == null && bytes.isNotEmpty) {
      final ext = _extensionFromBytes(bytes);
      name = filename.contains('.') ? filename : 'image.$ext';
      contentType = ext == 'png'
          ? MediaType('image', 'png')
          : ext == 'jpg'
              ? MediaType('image', 'jpeg')
              : MediaType('image', 'webp');
    }
    final uri = Uri.parse('$baseUrl/academies/$id/logo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: name,
        contentType: contentType,
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    _invalidateHomeHeaderCache();
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy> uploadAcademyScheduleImage(
      String id, Uint8List bytes, String filename) async {
    var name = filename;
    var contentType = _contentTypeFromFilename(filename);
    if (contentType == null && bytes.isNotEmpty) {
      final ext = _extensionFromBytes(bytes);
      name = filename.contains('.') ? filename : 'schedule.$ext';
      contentType = ext == 'png'
          ? MediaType('image', 'png')
          : ext == 'jpg'
              ? MediaType('image', 'jpeg')
              : MediaType('image', 'webp');
    }
    final uri = Uri.parse('$baseUrl/academies/$id/schedule_image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: name,
        contentType: contentType,
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    _invalidateHomeHeaderCache();
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Importa alunos em lote por Excel (.xlsx) para uma academia.
  ///
  /// Endpoint: `POST /academies/{academyId}/students/bulk-import` (multipart field `file`).
  /// Retorna um JSON com `summary` e `results` (erros por linha, criados, pulados).
  Future<Map<String, dynamic>> bulkImportStudentsXlsx({
    required String academyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/students/bulk-import');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.isNotEmpty ? filename : 'alunos.xlsx',
        contentType: MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    invalidateCache('GET:$baseUrl/users');
    return (data ?? <String, dynamic>{}) as Map<String, dynamic>;
  }

  /// Atualiza academia (nome, slug, tema, técnicas, lição visível). Campos omitidos não são alterados.
  /// Se [updateVisibleLesson] for true, envia [visibleLessonId] (null limpa a lição visível).
  Future<Academy> updateAcademy(
    String id, {
    String? name,
    String? slug,
    String? weeklyTheme,
    String? logoUrl,
    String? scheduleImageUrl,
    String? weeklyTechniqueId,
    String? visibleLessonId,
    bool updateVisibleLesson = false,
    bool? showTrophies,
    bool? showPartners,
    bool? showSchedule,
    bool? showGlobalSupporters,
    bool? faceRecognitionEnabled,
    bool? qrAttendanceEnabled,
    bool? octophotosEnabled,
    int? userPhotosQuota,
    bool? preCheckinEnabled,
    bool? preCheckinStrict,
    bool? faceCheckinEnabled,
    int? punctualityXp,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (weeklyTheme != null) body['weekly_theme'] = weeklyTheme;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (scheduleImageUrl != null) body['schedule_image_url'] = scheduleImageUrl;
    if (weeklyTechniqueId != null)
      body['weekly_technique_id'] = weeklyTechniqueId;
    if (updateVisibleLesson) body['visible_lesson_id'] = visibleLessonId;
    if (showTrophies != null) body['show_trophies'] = showTrophies;
    if (showPartners != null) body['show_partners'] = showPartners;
    if (showSchedule != null) body['show_schedule'] = showSchedule;
    if (showGlobalSupporters != null) {
      body['show_global_supporters'] = showGlobalSupporters;
    }
    if (faceRecognitionEnabled != null) {
      body['face_recognition_enabled'] = faceRecognitionEnabled;
    }
    if (qrAttendanceEnabled != null) {
      body['qr_attendance_enabled'] = qrAttendanceEnabled;
    }
    if (octophotosEnabled != null) {
      body['octophotos_enabled'] = octophotosEnabled;
    }
    if (userPhotosQuota != null) {
      body['user_photos_quota'] = userPhotosQuota;
    }
    if (preCheckinEnabled != null) {
      body['pre_checkin_enabled'] = preCheckinEnabled;
    }
    if (preCheckinStrict != null) {
      body['pre_checkin_strict'] = preCheckinStrict;
    }
    if (faceCheckinEnabled != null) {
      body['face_checkin_enabled'] = faceCheckinEnabled;
    }
    if (punctualityXp != null) {
      body['punctuality_xp'] = punctualityXp;
    }
    if (body.isEmpty) return getAcademy(id);
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
    _invalidateHomeHeaderCache();
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza o aviso ao abrir a home (título, corpo, URL e ativo). Strings vazias viram `null` na API.
  Future<Academy> updateAcademyLoginNotice(
    String id, {
    required String? loginNoticeTitle,
    required String? loginNoticeBody,
    required String? loginNoticeUrl,
    required bool loginNoticeActive,
  }) async {
    String? norm(String? s) {
      final t = s?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final body = <String, dynamic>{
      'login_notice_title': norm(loginNoticeTitle),
      'login_notice_body': norm(loginNoticeBody),
      'login_notice_url': norm(loginNoticeUrl),
      'login_notice_active': loginNoticeActive,
    };
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
    _invalidateHomeHeaderCache();
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteAcademy(String id) async {
    final r = await _req(_client.delete(Uri.parse('$baseUrl/academies/$id'),
        headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
  }

  // ---------- Users ----------
  /// [asRealUser] true = não envia impersonation (para o seletor "Atuar como" carregar como admin e permitir voltar).
  /// Lista utilizadores com paginação (máx. 50 por pedido na API).
  Future<List<UserModel>> getUsers(
      {String? academyId,
      bool asRealUser = false,
      int offset = 0,
      int limit = 50,
      String? search,
      String? graduation}) async {
    var queryParams = <String, String>{};
    if (academyId != null && academyId.isNotEmpty) {
      queryParams['academy_id'] = academyId;
    }
    if (offset > 0) queryParams['offset'] = offset.toString();
    if (limit != 50) queryParams['limit'] = limit.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (graduation != null && graduation.isNotEmpty) queryParams['graduation'] = graduation;
    var uri = Uri.parse('$baseUrl/users');
    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final r = (asRealUser || search != null || graduation != null)
        ? await _req(_client.get(uri,
            headers: await _headers(auth: true, realUserOnly: asRealUser)))
        : await _getWithCache(uri, _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Estatísticas de todos os alunos da academia no período informado.
  Future<Map<String, UserAcademyStats>> getAcademyStudentStats({
    required DateTime fromDate,
    required DateTime toDate,
    String? academyId,
  }) async {
    final params = <String, String>{
      'from_date': '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
      'to_date': '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
    };
    if (academyId != null && academyId.isNotEmpty) params['academy_id'] = academyId;
    final uri = Uri.parse('$baseUrl/users/academy-stats').replace(queryParameters: params);
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return {
      for (final e in list)
        (e as Map<String, dynamic>)['user_id'] as String: UserAcademyStats.fromJson(e),
    };
  }

  /// Cache da lista completa (o diálogo "Atuar como" reabre com frequência e
  /// cada chamada são 1+ requests de 50 em 50). Limpo em [invalidateCache].
  final Map<String, ({List<UserModel> users, int expiresAtMs})> _usersAllCache =
      {};

  /// Acumula todas as páginas de utilizadores (50 por pedido).
  Future<List<UserModel>> getUsersAll(
      {String? academyId, bool asRealUser = false}) async {
    final cacheKey = 'usersAll:${academyId ?? ''}:$asRealUser';
    final cached = _usersAllCache[cacheKey];
    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch < cached.expiresAtMs) {
      return cached.users;
    }
    const page = 50;
    final all = <UserModel>[];
    var offset = 0;
    while (true) {
      final batch = await getUsers(
        academyId: academyId,
        asRealUser: asRealUser,
        offset: offset,
        limit: page,
      );
      all.addAll(batch);
      if (batch.length < page) break;
      offset += page;
    }
    _usersAllCache[cacheKey] = (
      users: all,
      expiresAtMs:
          DateTime.now().millisecondsSinceEpoch + (_cacheTtlMedium * 1000),
    );
    return all;
  }

  // --- Attendance (Chamada por QR) ---

  Future<AttendanceSessionModel> createAttendanceSession(
      {String? title, int? expiresInMinutes, String? trainingSessionId}) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions');
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (expiresInMinutes != null) body['expires_in_minutes'] = expiresInMinutes;
    if (trainingSessionId != null) body['training_session_id'] = trainingSessionId;
    final r = await _req(_client.post(uri,
        headers: await _jsonHeaders(auth: true), body: jsonEncode(body)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    return AttendanceSessionModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<AttendanceSessionModel> getAttendanceSession(String sessionId) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId');
    // Sem cache: estado da chamada deve refletir presença em tempo real.
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceSessionModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<List<AttendanceRecordModel>> getAttendanceSessionRecords(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/records')
        .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
    // Sem cache: lista precisa atualizar assim que o aluno confirma presença.
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = (data as List<dynamic>? ?? const []);
    return list
        .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A API limita a 50 registos por pedido; acumula todas as páginas (ordenadas por checked_in_at).
  Future<List<AttendanceRecordModel>> getAttendanceSessionRecordsAll(
      String sessionId) async {
    const page = 50;
    final all = <AttendanceRecordModel>[];
    var offset = 0;
    while (true) {
      final batch = await getAttendanceSessionRecords(sessionId,
          limit: page, offset: offset);
      all.addAll(batch);
      if (batch.length < page) break;
      offset += page;
    }
    return all;
  }

  /// Lista sessões de chamada da academia (professor/gerente) ou todas (admin).
  Future<List<AttendanceSessionModel>> listAttendanceSessions({
    String? status,
    bool mine = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'mine': mine ? 'true' : 'false',
    };
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (dateFrom != null) qp['date_from'] = dateFrom.toUtc().toIso8601String();
    if (dateTo != null) qp['date_to'] = dateTo.toUtc().toIso8601String();
    final uri =
        Uri.parse('$baseUrl/attendance/sessions').replace(queryParameters: qp);
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = (data as List<dynamic>? ?? const []);
    return list
        .map((e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Presença manual (professor/gestor) sem QR.
  Future<AttendanceRecordModel> addAttendanceRecord(
      String sessionId, String userId) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/records');
    final r = await _req(_client.post(
      uri,
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'user_id': userId}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    return AttendanceRecordModel.fromJson(data! as Map<String, dynamic>);
  }

  /// Lista paginada de alunos da academia (`GET /students/academy/{id}/list`).
  Future<List<AcademyStudentListItem>> getAcademyStudentsList(
    String academyId, {
    bool asRealUser = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/students/academy/$academyId/list')
        .replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    http.Response r;
    try {
      r = asRealUser
          ? await _req(
              _client.get(uri,
                  headers: await _headers(auth: true, realUserOnly: true)),
              timeout: _getTimeout,
            )
          : await _req(
              _client.get(uri, headers: await _headers(auth: true)),
              timeout: _getTimeout,
            );
    } on ApiException catch (e) {
      if (e.statusCode == 403 && !asRealUser && AuthService().isRealUserAdmin) {
        return getAcademyStudentsList(
          academyId,
          asRealUser: true,
          offset: offset,
          limit: limit,
        );
      }
      rethrow;
    }
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data as List<dynamic>? ?? const [];
    return list
        .map((e) => AcademyStudentListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AcademyStudentListItem>> getAcademyStudentsListAll(
    String academyId, {
    bool asRealUser = false,
  }) async {
    const pageSize = 50;
    final all = <AcademyStudentListItem>[];
    var offset = 0;
    while (true) {
      final page = await getAcademyStudentsList(
        academyId,
        asRealUser: asRealUser,
        offset: offset,
        limit: pageSize,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  /// Várias presenças manuais (`POST .../records` com `student_ids`).
  Future<List<AttendanceRecordModel>> addAttendanceRecordsManualBatch(
      String sessionId, List<String> studentIds) async {
    if (studentIds.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/records');
    final payload = await _encodeJsonPayload({'student_ids': studentIds});
    final r = await _req(_client.post(
      uri,
      headers: await _jsonHeaders(auth: true),
      body: payload,
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    final map = data! as Map<String, dynamic>;
    final raw = map['records'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FaceRecognitionSubmitResponse> submitFaceRecognitionPhoto({
    required String sessionId,
    required Uint8List bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final uri = Uri.parse('$baseUrl/face-recognition/submit');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.fields['session_id'] = sessionId;
    final media = contentType.toLowerCase().contains('png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: filename.isNotEmpty ? filename : 'face_checkin.jpg',
        contentType: media,
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return FaceRecognitionSubmitResponse.fromJson(
        data! as Map<String, dynamic>);
  }

  Future<FaceRecognitionJobStatusModel> getFaceRecognitionJob(
      String jobId) async {
    final uri = Uri.parse('$baseUrl/face-recognition/job/$jobId');
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return FaceRecognitionJobStatusModel.fromJson(
        data! as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> confirmFaceRecognition({
    required String sessionId,
    required String jobId,
    required List<String> confirmedStudentIds,
  }) async {
    final uri = Uri.parse('$baseUrl/face-recognition/confirm');
    final r = await _req(_client.post(
      uri,
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({
        'session_id': sessionId,
        'job_id': jobId,
        'confirmed_student_ids': confirmedStudentIds,
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    return data! as Map<String, dynamic>;
  }

  Future<void> generateFaceEmbedding(String studentId) async {
    final uri =
        Uri.parse('$baseUrl/face-recognition/generate-embedding/$studentId');
    final r = await _req(_client.post(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  Future<FaceRecognitionEmbeddingStatusModel> getFaceEmbeddingStatus(
      {String? academyId}) async {
    final uri = academyId != null && academyId.isNotEmpty
        ? Uri.parse('$baseUrl/face-recognition/embedding-status')
            .replace(queryParameters: {'academy_id': academyId})
        : Uri.parse('$baseUrl/face-recognition/embedding-status');
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return FaceRecognitionEmbeddingStatusModel.fromJson(
        data! as Map<String, dynamic>);
  }

  /// Remove um registo de presença (correção).
  Future<void> deleteAttendanceRecord(String recordId) async {
    final uri = Uri.parse('$baseUrl/attendance/records/$recordId');
    final r = await _req(_client.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    _invalidateAttendanceCache();
  }

  /// Estatísticas: sessões criadas por um professor (`professor_id` omitido = utilizador atual).
  Future<List<AttendanceSessionStatModel>> getAttendanceStatsSessions({
    String? professorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, String>{};
    if (professorId != null && professorId.isNotEmpty)
      qp['professor_id'] = professorId;
    if (from != null) qp['from'] = from.toUtc().toIso8601String();
    if (to != null) qp['to'] = to.toUtc().toIso8601String();
    final uri = Uri.parse('$baseUrl/attendance/stats/sessions')
        .replace(queryParameters: qp);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = (data as List<dynamic>? ?? const []);
    return list
        .map((e) =>
            AttendanceSessionStatModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Estatísticas: frequência de todos os alunos da academia no período.
  Future<List<AttendanceStudentStatModel>> getAttendanceStatsStudents({
    String? academyId,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, String>{};
    if (academyId != null && academyId.isNotEmpty) qp['academy_id'] = academyId;
    if (from != null) qp['from'] = from.toUtc().toIso8601String();
    if (to != null) qp['to'] = to.toUtc().toIso8601String();
    final uri = Uri.parse('$baseUrl/attendance/stats/students')
        .replace(queryParameters: qp);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = (data as List<dynamic>? ?? const []);
    return list
        .map((e) =>
            AttendanceStudentStatModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detalhe de frequência de um aluno (histórico de presenças no período).
  Future<AttendanceStudentDetailModel> getAttendanceStatsStudent(
    String studentId, {
    String? academyId,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = <String, String>{};
    if (academyId != null && academyId.isNotEmpty) qp['academy_id'] = academyId;
    if (from != null) qp['from'] = from.toUtc().toIso8601String();
    if (to != null) qp['to'] = to.toUtc().toIso8601String();
    final uri = Uri.parse('$baseUrl/attendance/stats/students/$studentId')
        .replace(queryParameters: qp);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceStudentDetailModel.fromJson(data! as Map<String, dynamic>);
  }

  /// Frequência do utilizador logado (`/attendance/stats/me`): período, buckets para gráfico e histórico paginado.
  Future<AttendanceMyStatsModel> getAttendanceMyStats({
    DateTime? from,
    DateTime? to,
    int limit = 30,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (from != null) qp['from'] = from.toUtc().toIso8601String();
    if (to != null) qp['to'] = to.toUtc().toIso8601String();
    final uri =
        Uri.parse('$baseUrl/attendance/stats/me').replace(queryParameters: qp);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceMyStatsModel.fromJson(data! as Map<String, dynamic>);
  }

  Uri _buildAttendanceRankingUri({
    required String academyId,
    required String periodKind,
    String? month,
    int? year,
    int? quarter,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 10,
  }) {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final qp = <String, String>{
      'academy_id': academyId,
      'period': periodKind,
      'limit': '$limit',
    };
    if (periodKind == 'month' && month != null && month.isNotEmpty) {
      qp['month'] = month;
    }
    if ((periodKind == 'quarter' || periodKind == 'year') && year != null) {
      qp['year'] = '$year';
    }
    if (periodKind == 'quarter' && quarter != null) {
      qp['quarter'] = '$quarter';
    }
    if (periodKind == 'custom' && dateFrom != null && dateTo != null) {
      qp['date_from'] = ymd(dateFrom);
      qp['date_to'] = ymd(dateTo);
    }
    return Uri.parse('$baseUrl/attendance/ranking')
        .replace(queryParameters: qp);
  }

  Future<AttendanceRankingModel> fetchAttendanceRanking({
    required String academyId,
    required String periodKind,
    String? month,
    int? year,
    int? quarter,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 10,
  }) async {
    final uri = _buildAttendanceRankingUri(
      academyId: academyId,
      periodKind: periodKind,
      month: month,
      year: year,
      quarter: quarter,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
    );
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceRankingModel.fromJson(data! as Map<String, dynamic>);
  }

  void invalidateAttendanceRankingCache({
    String? academyId,
    String? periodKind,
    String? month,
    int? year,
    int? quarter,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 10,
  }) {
    if (academyId == null ||
        academyId.isEmpty ||
        periodKind == null ||
        periodKind.isEmpty) {
      invalidateCache('GET:$baseUrl/attendance/ranking');
      return;
    }
    final uri = _buildAttendanceRankingUri(
      academyId: academyId,
      periodKind: periodKind,
      month: month,
      year: year,
      quarter: quarter,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
    );
    invalidateCache('GET:${uri.toString()}');
  }

  Future<QrTokenModel> getAttendanceQrToken(String sessionId,
      {int ttlSeconds = 60}) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/qr')
        .replace(queryParameters: {'ttl_seconds': '$ttlSeconds'});
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return QrTokenModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<AttendanceRecordModel> scanAttendance(String token) async {
    final uri = Uri.parse('$baseUrl/attendance/scan');
    final r = await _req(_client.post(
      uri,
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'token': token}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    return AttendanceRecordModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<AttendanceSessionModel> closeAttendanceSession(
      String sessionId) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/close');
    final r = await _req(_client.post(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    _invalidateAttendanceCache();
    return AttendanceSessionModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<AttendanceUserSummaryModel> getAttendanceMeSummary(
      {int fromDays = 30}) async {
    final uri = Uri.parse('$baseUrl/attendance/me/summary')
        .replace(queryParameters: {'from_days': '$fromDays'});
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceUserSummaryModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<AttendanceUserSummaryModel> getAttendanceUserSummary(String userId,
      {int fromDays = 30}) async {
    final uri = Uri.parse('$baseUrl/attendance/users/$userId/summary')
        .replace(queryParameters: {'from_days': '$fromDays'});
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AttendanceUserSummaryModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getUserPoints(String userId) async {
    final r = await _req(_client.get(Uri.parse('$baseUrl/users/$userId/points'),
        headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Pontos de todos os usuários da academia em uma requisição (evita N+1 na tela de pontos).
  Future<Map<String, int>> getAcademyUserPoints(String academyId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/$academyId/user_points'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final byUser = map['points_by_user'] as Map<String, dynamic>? ?? {};
    return byUser.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<Map<String, dynamic>> getPointsLog(String userId,
      {int limit = 50, int offset = 0}) async {
    final uri = Uri.parse('$baseUrl/users/$userId/points_log').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
        });
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Galeria de troféus do usuário (troféus da academia com tier conquistado).
  Future<List<TrophyWithEarned>> getTrophiesForUser(String userId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/trophies/user/$userId'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => TrophyWithEarned.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Troféus conquistados por cada usuário da academia (uma query só).
  Future<Map<String, List<AcademyUserEarnedItem>>> getAcademyEarned(String academyId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/trophies/academy-earned?academy_id=$academyId'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    final map = <String, List<AcademyUserEarnedItem>>{};
    for (final e in list) {
      final entry = AcademyUserEarned.fromJson(e as Map<String, dynamic>);
      map[entry.userId] = entry.items;
    }
    return map;
  }

  /// Resumo dos cards de troféus da home: conquistas recentes do usuário e feed da academia.
  Future<TrophyHomeSummary> getTrophyHomeSummary() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/trophies/me/home-summary'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return TrophyHomeSummary.fromJson(data as Map<String, dynamic>);
  }

  /// Lista troféus da academia (admin). [cacheBust] evita resposta HTTP antiga no browser.
  Future<List<Map<String, dynamic>>> getTrophies(
    String academyId, {
    bool cacheBust = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'academy_id': academyId,
      'limit': '$limit',
      'offset': '$offset',
    };
    if (cacheBust) {
      params['_t'] = DateTime.now().microsecondsSinceEpoch.toString();
    }
    final uri = Uri.parse('$baseUrl/trophies').replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Cria troféu ou medalha da academia (admin).
  Future<Map<String, dynamic>> createTrophy({
    required String academyId,
    required String techniqueId,
    required String name,
    required String startDate,
    required String endDate,
    required int targetCount,
    required String awardKind,
    int? minDurationDays,
    int minRewardLevelToUnlock = 0,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'technique_id': techniqueId,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'target_count': targetCount,
      'award_kind': awardKind,
    };
    if (minDurationDays != null) body['min_duration_days'] = minDurationDays;
    if (minRewardLevelToUnlock != 0) {
      body['min_reward_level_to_unlock'] = minRewardLevelToUnlock;
    }
    if (minGraduationToUnlock != null && minGraduationToUnlock.isNotEmpty)
      body['min_graduation_to_unlock'] = minGraduationToUnlock;
    if (maxCountPerOpponent != null)
      body['max_count_per_opponent'] = maxCountPerOpponent;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/trophies'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/trophies');
    return data! as Map<String, dynamic>;
  }

  /// Atualiza troféu/medalha (PATCH). Apenas chaves não nulas entram no body.
  Future<Map<String, dynamic>> updateTrophy(
    String trophyId, {
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,

    /// Quando true, envia [maxCountPerOpponent] no PATCH (inclui null para remover o limite).
    bool setMaxCountPerOpponent = false,
  }) async {
    final body = <String, dynamic>{};
    if (techniqueId != null) body['technique_id'] = techniqueId;
    if (name != null) body['name'] = name;
    if (startDate != null) body['start_date'] = startDate;
    if (endDate != null) body['end_date'] = endDate;
    if (targetCount != null) body['target_count'] = targetCount;
    if (awardKind != null) body['award_kind'] = awardKind;
    if (minDurationDays != null) body['min_duration_days'] = minDurationDays;
    if (minRewardLevelToUnlock != null) {
      body['min_reward_level_to_unlock'] = minRewardLevelToUnlock;
    }
    if (minGraduationToUnlock != null) {
      body['min_graduation_to_unlock'] =
          minGraduationToUnlock.isEmpty ? null : minGraduationToUnlock;
    }
    if (setMaxCountPerOpponent) {
      body['max_count_per_opponent'] = maxCountPerOpponent;
    }
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/trophies/${Uri.encodeComponent(trophyId)}'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/trophies');
    return data! as Map<String, dynamic>;
  }

  /// Remove troféu (soft delete no servidor).
  Future<void> deleteTrophy(String trophyId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/trophies/${Uri.encodeComponent(trophyId)}'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
    invalidateCache('GET:$baseUrl/trophies');
  }

  /// Lista parceiros da academia (alunos: sem academy_id usa a do usuário; gestor/admin: academy_id obrigatório para admin).
  Future<List<Partner>> getPartners(
    String? academyId, {
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (academyId != null && academyId.isNotEmpty) {
      queryParams['academy_id'] = academyId;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final uri =
        Uri.parse('$baseUrl/partners').replace(queryParameters: queryParams);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => Partner.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lista parceiros globais em destaque para o banner da Central.
  Future<List<GlobalPartner>> getFeaturedPartners() async {
    final uri = Uri.parse('$baseUrl/partners/featured');
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => GlobalPartner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria parceiro na academia.
  Future<Partner> createPartner({
    required String academyId,
    required String name,
    String? description,
    String? url,
    String? logoUrl,
    String? buttonLabel,
    bool highlightOnLogin = false,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
    };
    if (description != null && description.isNotEmpty)
      body['description'] = description;
    if (url != null && url.isNotEmpty) body['url'] = url;
    if (logoUrl != null && logoUrl.isNotEmpty) body['logo_url'] = logoUrl;
    if (buttonLabel != null && buttonLabel.isNotEmpty)
      body['button_label'] = buttonLabel;
    body['highlight_on_login'] = highlightOnLogin;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/partners'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/partners');
    return Partner.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza parceiro.
  Future<Partner> updatePartner({
    required String partnerId,
    required String academyId,
    String? name,
    String? description,
    String? url,
    String? logoUrl,
    String? buttonLabel,
    bool? highlightOnLogin,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (url != null) body['url'] = url;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (buttonLabel != null) body['button_label'] = buttonLabel;
    if (highlightOnLogin != null) body['highlight_on_login'] = highlightOnLogin;
    final uri = Uri.parse('$baseUrl/partners/$partnerId')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(_client.put(uri,
        headers: await _jsonHeaders(auth: true), body: jsonEncode(body)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/partners');
    return Partner.fromJson(data! as Map<String, dynamic>);
  }

  /// Remove parceiro.
  Future<void> deletePartner(String partnerId, String academyId) async {
    final uri = Uri.parse('$baseUrl/partners/$partnerId')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(_client.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/partners');
  }

  /// Lista parceiros globais (somente admin global).
  Future<List<GlobalPartner>> getGlobalPartnersAdmin() async {
    final uri = Uri.parse('$baseUrl/admin/global_partners');
    final r = await _req(
        _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => GlobalPartner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria parceiro global (somente admin global).
  Future<GlobalPartner> createGlobalPartner({
    required String name,
    String? description,
    String? logoUrl,
    String? offerText,
    String? externalUrl,
    String? buttonLabel,
    int? featuredOrder,
    bool isActive = true,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };
    if (description != null && description.isNotEmpty)
      body['description'] = description;
    if (logoUrl != null && logoUrl.isNotEmpty) body['logo_url'] = logoUrl;
    if (offerText != null && offerText.isNotEmpty)
      body['offer_text'] = offerText;
    if (externalUrl != null && externalUrl.isNotEmpty)
      body['external_url'] = externalUrl;
    if (buttonLabel != null && buttonLabel.isNotEmpty)
      body['button_label'] = buttonLabel;
    if (featuredOrder != null) body['featured_order'] = featuredOrder;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/admin/global_partners'),
      headers: await _jsonHeaders(auth: true, realUserOnly: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/partners/featured');
    return GlobalPartner.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza parceiro global (somente admin global).
  Future<GlobalPartner> updateGlobalPartner({
    required String id,
    String? name,
    String? description,
    String? logoUrl,
    String? offerText,
    String? externalUrl,
    String? buttonLabel,
    int? featuredOrder,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (offerText != null) body['offer_text'] = offerText;
    if (externalUrl != null) body['external_url'] = externalUrl;
    if (buttonLabel != null) body['button_label'] = buttonLabel;
    if (featuredOrder != null) body['featured_order'] = featuredOrder;
    if (isActive != null) body['is_active'] = isActive;
    final r = await _req(_client.put(
      Uri.parse('$baseUrl/admin/global_partners/$id'),
      headers: await _jsonHeaders(auth: true, realUserOnly: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/partners/featured');
    return GlobalPartner.fromJson(data! as Map<String, dynamic>);
  }

  /// Remove parceiro global (somente admin global).
  Future<void> deleteGlobalPartner(String id) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/admin/global_partners/$id'),
      headers: await _headers(auth: true, realUserOnly: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/partners/featured');
  }

  Future<UserModel> getUser(String id) async {
    final r = await _req(_client.get(Uri.parse('$baseUrl/users/$id'),
        headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> createUser({
    required String email,
    String? name,
    String? graduation,
    String? role,
    String? password,
    String? academyId,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'name': name,
      'academy_id': academyId,
    };
    if (graduation != null) body['graduation'] = graduation;
    if (role != null) body['role'] = role;
    if (password != null && password.isNotEmpty) body['password'] = password;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/users'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    // Limpar cache de listagem de usuários para refletir imediatamente o novo usuário.
    invalidateCache('GET:$baseUrl/users');
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(
    String id, {
    String? email,
    String? name,
    String? graduation,
    String? role,
    String? password,
    String? academyId,
    int? pointsAdjustment,
    String? avatarUrl,
    bool sendAccountFreezeFields = false,
    bool? accountFrozen,
    String? accountFreezeReason,
  }) async {
    final body = <String, dynamic>{};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (name != null) body['name'] = name;
    if (graduation != null) body['graduation'] = graduation;
    if (role != null) body['role'] = role;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (academyId != null) body['academy_id'] = academyId;
    if (pointsAdjustment != null) body['points_adjustment'] = pointsAdjustment;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (sendAccountFreezeFields) {
      body['account_frozen'] = accountFrozen ?? false;
      body['account_freeze_reason'] = accountFreezeReason;
    }
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/users/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/users');
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> uploadMyAvatar({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final safeFilename = filename.trim().isEmpty ? 'avatar.jpg' : filename.trim();
    final uri = Uri.parse('$baseUrl/users/me/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeFilename,
        contentType:
            _mediaTypeFromContentTypeOrFilename(contentType, safeFilename, bytes),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    invalidateCache('GET:$baseUrl/users');
    _invalidateHomeHeaderCache();
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> uploadMyFacialPhoto({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final safeFilename = filename.trim().isEmpty ? 'facial.jpg' : filename.trim();
    final uri = Uri.parse('$baseUrl/users/me/facial-photo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeFilename,
        contentType:
            _mediaTypeFromContentTypeOrFilename(contentType, safeFilename, bytes),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> uploadUserAvatar(
    String userId, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final safeFilename = filename.trim().isEmpty ? 'avatar.jpg' : filename.trim();
    final uri = Uri.parse('$baseUrl/users/$userId/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeFilename,
        contentType:
            _mediaTypeFromContentTypeOrFilename(contentType, safeFilename, bytes),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    invalidateCache('GET:$baseUrl/users');
    _invalidateHomeHeaderCache();
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id, {required String confirmEmail}) async {
    final uri = Uri.parse('$baseUrl/users/$id').replace(
      queryParameters: {'confirm_email': confirmEmail},
    );
    final r = await _req(_client.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    // Limpar cache de listagem de usuários após exclusão.
    invalidateCache('GET:$baseUrl/users');
  }

  /// Administrador: reverte confirmação de uma execução (`POST /admin/executions/{id}/revert_confirmation`).
  Future<Map<String, dynamic>> adminRevertExecutionConfirmation(
      String executionId) async {
    final uri =
        Uri.parse('$baseUrl/admin/executions/$executionId/revert_confirmation');
    final r = await _req(_client.post(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/users');
    return data! as Map<String, dynamic>;
  }

  /// Administrador: remove um registo de conclusão de missão (`POST /admin/mission_usages/{id}/void`).
  Future<Map<String, dynamic>> adminVoidMissionUsage(String usageId) async {
    final uri = Uri.parse('$baseUrl/admin/mission_usages/$usageId/void');
    final r = await _req(_client.post(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/users');
    return data! as Map<String, dynamic>;
  }

  // ---------- Lessons ----------
  /// Lista lições. Se [academyId] for informado e a academia tiver lição visível, retorna só ela.
  Future<List<Lesson>> getLessons(
      {String? academyId, int offset = 0, int limit = 50, String? search}) async {
    var queryParams = <String, String>{};
    if (academyId != null) queryParams['academy_id'] = academyId;
    if (offset > 0) queryParams['offset'] = offset.toString();
    if (limit != 50) queryParams['limit'] = limit.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final uri = queryParams.isNotEmpty
        ? Uri.parse('$baseUrl/lessons').replace(queryParameters: queryParams)
        : Uri.parse('$baseUrl/lessons');
    final r = search != null && search.isNotEmpty
        ? await _req(_client.get(uri, headers: await _headers(auth: true)))
        : await _getWithCache(uri, _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Lesson> getLesson(String id) async {
    final r = await _req(_client.get(Uri.parse('$baseUrl/lessons/$id'),
        headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<Lesson> createLesson({
    required String techniqueId,
    required String title,
    String? slug,
    String? videoUrl,
    String? content,
    int orderIndex = 0,
  }) async {
    final body = <String, dynamic>{
      'technique_id': techniqueId,
      'title': title,
      'video_url': videoUrl,
      'content': content,
      'order_index': orderIndex,
    };
    if (slug != null && slug.trim().isNotEmpty) body['slug'] = slug.trim();
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/lessons'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/lessons');
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<Lesson> updateLesson(
    String id, {
    String? techniqueId,
    String? title,
    String? slug,
    String? videoUrl,
    String? content,
    int? orderIndex,
  }) async {
    final body = <String, dynamic>{};
    if (techniqueId != null) body['technique_id'] = techniqueId;
    if (title != null) body['title'] = title;
    if (slug != null) body['slug'] = slug;
    if (videoUrl != null) body['video_url'] = videoUrl;
    if (content != null) body['content'] = content;
    if (orderIndex != null) body['order_index'] = orderIndex;
    final r = await _req(_client.put(
      Uri.parse('$baseUrl/lessons/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteLesson(String id) async {
    final r = await _req(_client.delete(Uri.parse('$baseUrl/lessons/$id'),
        headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/lessons');
  }

  // ---------- Techniques ----------
  /// Lista técnicas da academia (para vínculo a troféus e posições da semana). [academyId] obrigatório.
  /// [_cacheBust] evita respostas antigas em cache HTTP do browser (web) após CRUD.
  Future<List<Technique>> getTechniques({
    required String academyId,
    bool cacheBust = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'academy_id': academyId,
      'limit': '$limit',
      'offset': '$offset',
    };
    if (cacheBust) {
      params['_t'] = DateTime.now().microsecondsSinceEpoch.toString();
    }
    final uri = Uri.parse('$baseUrl/techniques').replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => Technique.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Technique> getTechnique(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques/$id')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<Technique> createTechnique({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
    };
    if (slug != null && slug.trim().isNotEmpty) body['slug'] = slug.trim();
    if (description != null) body['description'] = description;
    if (videoUrl != null && videoUrl.trim().isNotEmpty) {
      body['video_url'] = videoUrl.trim();
    }
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/techniques'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/techniques');
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<Technique> updateTechnique(
    String id, {
    required String academyId,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (description != null) body['description'] = description;
    if (videoUrl != null) {
      body['video_url'] = videoUrl.trim().isEmpty ? null : videoUrl.trim();
    }
    final uri = Uri.parse('$baseUrl/techniques/$id')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(_client.put(
      uri,
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/techniques');
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteTechnique(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques/$id')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(_client.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/techniques');
  }

  // ---------- Missions ----------
  Future<List<Mission>> getMissions({int offset = 0, int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/missions').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => Mission.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Mission> getMission(String id) async {
    final r = await _req(_client.get(Uri.parse('$baseUrl/missions/$id'),
        headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Mission.fromJson(data! as Map<String, dynamic>);
  }

  Future<Mission> createMission({
    required String techniqueId,
    required String startDate,
    required String endDate,
    String level = 'beginner',
    String? theme,
    String? academyId,
    int multiplier = minRewardPoints,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/missions'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({
        'technique_id': techniqueId,
        'start_date': startDate,
        'end_date': endDate,
        'level': level,
        'theme': theme,
        'academy_id': academyId,
        'multiplier': multiplier,
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/missions');
    return Mission.fromJson(data! as Map<String, dynamic>);
  }

  Future<Mission> updateMission(
    String id, {
    String? techniqueId,
    String? startDate,
    String? endDate,
    String? level,
    String? theme,
    String? academyId,
    int? multiplier,
  }) async {
    final body = <String, dynamic>{};
    if (techniqueId != null) body['technique_id'] = techniqueId;
    if (startDate != null) body['start_date'] = startDate;
    if (endDate != null) body['end_date'] = endDate;
    if (level != null) body['level'] = level;
    if (theme != null) body['theme'] = theme;
    if (academyId != null) body['academy_id'] = academyId;
    if (multiplier != null) body['multiplier'] = multiplier;
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/missions/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/missions');
    return Mission.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteMission(String id) async {
    final r = await _req(_client.delete(Uri.parse('$baseUrl/missions/$id'),
        headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/missions');
  }

  // ---------- Área do aluno (missão do dia, conclusão, histórico, feedback, métricas) ----------
  Future<MissionToday> getMissionToday({
    String level = 'beginner',
    String? academyId,
  }) async {
    var uri = Uri.parse('$baseUrl/mission_today').replace(queryParameters: {
      'level': level,
      if (academyId != null) 'academy_id': academyId,
    });
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionToday.fromJson(data! as Map<String, dynamic>);
  }

  /// Missões da semana: modo legado (até 3 slots) ou **turmas** (escolha + focos 1–N).
  /// [level] mapeado da faixa do usuário: beginner (white/blue) ou intermediate (purple/brown/black).
  Future<MissionWeek> getMissionWeek({
    String level = 'beginner',
    String? academyId,
  }) async {
    final params = <String, String>{
      'level': level,
      if (academyId != null) 'academy_id': academyId,
    };
    var uri = Uri.parse('$baseUrl/mission_today/week')
        .replace(queryParameters: params);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionWeek.fromJson(data! as Map<String, dynamic>);
  }

  /// Escolha da turma da semana ISO (aluno). Invalida cache de [getMissionWeek].
  Future<void> putWeeklyKitChoice({
    required String kitId,
    String? referenceDate,
  }) async {
    final body = <String, dynamic>{
      'kit_id': kitId,
      if (referenceDate != null) 'reference_date': referenceDate,
    };
    final r = await _req(_client.put(
      Uri.parse('$baseUrl/users/me/weekly-kit-choice'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today/week');
  }

  // ---------------------------------------------------------------------------
  // Training sessions (pré-checkin)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getTrainingTemplates(String academyId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/$academyId/training-templates'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTrainingTemplate(
    String academyId, {
    String? label,
    required String startTime,
    int toleranceMinutes = 15,
    int sortOrder = 0,
  }) async {
    final body = <String, dynamic>{
      'start_time': startTime,
      'tolerance_minutes': toleranceMinutes,
      'sort_order': sortOrder,
    };
    if (label != null && label.isNotEmpty) body['label'] = label;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/training-templates'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<void> deleteTrainingTemplate(String templateId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/academies/training-templates/$templateId'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  Future<List<Map<String, dynamic>>> getTrainingSessions(
    String academyId, {
    String? classDate,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (classDate != null) params['class_date'] = classDate;
    if (status != null) params['status'] = status;
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/$academyId/training-sessions')
          .replace(queryParameters: params),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTrainingSessionsToday(String academyId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/$academyId/training-sessions/today'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTrainingSession(
    String academyId, {
    required String classDate,
    required String startTime,
    int toleranceMinutes = 15,
    String? label,
    String? templateId,
  }) async {
    final body = <String, dynamic>{
      'class_date': classDate,
      'start_time': startTime,
      'tolerance_minutes': toleranceMinutes,
    };
    if (label != null && label.isNotEmpty) body['label'] = label;
    if (templateId != null) body['template_id'] = templateId;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/training-sessions'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> openTrainingSession(String sessionId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/open'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeTrainingSession(String sessionId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/close'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<void> deleteTrainingSession(String sessionId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  // -------------------------------------------------------------------------
  // Pré-checkin
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPreCheckinStatus(String sessionId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/pre-checkin'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmPreCheckin(String sessionId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/pre-checkin/confirm'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelPreCheckin(String sessionId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/pre-checkin/cancel'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTrainingSessionSummary(String sessionId) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/academies/training-sessions/$sessionId/summary'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data as Map<String, dynamic>;
  }

  Future<List<WeeklyKitRead>> getWeeklyKits(String academyId) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/weekly-kits');
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data as List<dynamic>;
    return list
        .map((e) => WeeklyKitRead.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WeeklyKitRead> createWeeklyKit({
    required String academyId,
    required String label,
    int sortOrder = 0,
    List<Map<String, dynamic>>? items,
  }) async {
    final body = <String, dynamic>{
      'label': label,
      'sort_order': sortOrder,
      if (items != null) 'items': items,
    };
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/weekly-kits'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today/week');
    return WeeklyKitRead.fromJson(data! as Map<String, dynamic>);
  }

  Future<WeeklyKitRead> patchWeeklyKit({
    required String academyId,
    required String kitId,
    String? label,
    int? sortOrder,
    List<Map<String, dynamic>>? items,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (items != null) 'items': items,
    };
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/academies/$academyId/weekly-kits/$kitId'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today/week');
    return WeeklyKitRead.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteWeeklyKit(String academyId, String kitId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/academies/$academyId/weekly-kits/$kitId'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today/week');
  }

  /// Indica se a lição já foi concluída pelo usuário logado (para botão desabilitado ao abrir).
  Future<bool> getLessonCompleteStatus({required String lessonId}) async {
    final uri = Uri.parse('$baseUrl/lesson_complete/status')
        .replace(queryParameters: {'lesson_id': lessonId});
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return map['completed'] as bool? ?? false;
  }

  /// Corpo da resposta inclui `points_awarded` (pontos creditados nesta conclusão).
  Future<Map<String, dynamic>> postLessonComplete(
      {required String lessonId}) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/lesson_complete'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'lesson_id': lessonId}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today');
    invalidateCache('GET:$baseUrl/executions');
    _invalidateHomeHeaderCache();
    return data! as Map<String, dynamic>;
  }

  /// Conclusão por missão (missão do dia). usageType: before_training | after_training.
  /// Resposta inclui `points_awarded`.
  Future<Map<String, dynamic>> postMissionComplete({
    required String missionId,
    String usageType = 'after_training',
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/mission_complete'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'mission_id': missionId, 'usage_type': usageType}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today');
    invalidateCache('GET:$baseUrl/executions');
    _invalidateHomeHeaderCache();
    return data! as Map<String, dynamic>;
  }

  // ---------- Executions (gamificação) ----------
  /// Cria execução. Informe exatamente um de: missionId, lessonId, ou (techniqueId + academyId).
  Future<Map<String, dynamic>> postExecution({
    String? missionId,
    String? lessonId,
    String? techniqueId,
    String? academyId,
    required String opponentId,
    String usageType = 'after_training',
  }) async {
    final body = <String, dynamic>{
      'opponent_id': opponentId,
      'usage_type': usageType,
    };
    if (missionId != null) body['mission_id'] = missionId;
    if (lessonId != null) body['lesson_id'] = lessonId;
    if (techniqueId != null) body['technique_id'] = techniqueId;
    if (academyId != null) body['academy_id'] = academyId;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/executions'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today');
    invalidateCache('GET:$baseUrl/executions');
    return data! as Map<String, dynamic>;
  }

  /// Retorna apenas o número de confirmações pendentes do usuário logado (para badge na tela inicial).
  Future<int> getPendingConfirmationsCount() async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/executions/pending_confirmations/count'),
      _cacheTtlShort,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data is Map ? data as Map<String, dynamic> : null;
    return (map?['count'] as num?)?.toInt() ?? 0;
  }

  /// Retorna o número de indicações aguardando revisão do professor (para badge no card de gestão).
  Future<int> getProfessorReviewCount() async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/executions/professor_review/count'),
      _cacheTtlShort,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data is Map ? data as Map<String, dynamic> : null;
    return (map?['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getPendingConfirmations() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/executions/pending_confirmations'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> postExecutionConfirm({
    required String executionId,
    required String outcome,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/executions/$executionId/confirm'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'outcome': outcome}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/executions');
    return data! as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postExecutionReject({
    required String executionId,
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/executions/$executionId/reject'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/executions');
    return data! as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getProfessorReviewExecutions() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/executions/professor_review'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> postProfessorReviewExecution({
    required String executionId,
    required String outcome,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/executions/$executionId/professor_review'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'outcome': outcome}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/executions');
    return data! as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyExecutions() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/executions/my_executions'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<MissionHistoryItem>> getMissionUsagesHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri =
        Uri.parse('$baseUrl/mission_usages/history').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    });
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final list = map['missions'] as List<dynamic>? ?? [];
    return list
        .map((e) => MissionHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Histórico completo (pagina na API a 50 itens por pedido).
  Future<List<MissionHistoryItem>> getMissionUsagesHistoryAll() async {
    const page = 50;
    final all = <MissionHistoryItem>[];
    var offset = 0;
    while (true) {
      final batch = await getMissionUsagesHistory(limit: page, offset: offset);
      all.addAll(batch);
      if (batch.length < page) break;
      offset += page;
    }
    return all;
  }

  Future<void> postTrainingFeedback({
    String? observation,
  }) async {
    final body = <String, dynamic>{};
    if (observation != null && observation.isNotEmpty)
      body['observation'] = observation;
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/training_feedback'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  /// Métricas globais (admin/supervisor). Exige JWT; [realUserOnly] evita 403 em «Atuar como» aluno.
  Future<UsageMetrics> getMetricsUsage() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/metrics/usage'),
      headers: await _headers(auth: true, realUserOnly: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UsageMetrics.fromJson(data! as Map<String, dynamic>);
  }

  Future<UsageMetrics> getMetricsUsageForAcademy(String academyId) async {
    final uri = Uri.parse('$baseUrl/metrics/usage/by_academy')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UsageMetrics.fromJson(data! as Map<String, dynamic>);
  }

  Future<ProfessorImpact> getProfessorImpact({DateTime? referenceDate}) async {
    final params = <String, String>{};
    if (referenceDate != null) {
      params['reference_date'] =
          '${referenceDate.year.toString().padLeft(4, '0')}-${referenceDate.month.toString().padLeft(2, '0')}-${referenceDate.day.toString().padLeft(2, '0')}';
    }
    final uri = Uri.parse('$baseUrl/me/professor-impact')
        .replace(queryParameters: params.isEmpty ? null : params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return ProfessorImpact.fromJson(data! as Map<String, dynamic>);
  }

  Future<EngagementReport> getEngagementReport({
    required DateTime referenceDate,
    String? academyId,
  }) async {
    final params = <String, String>{
      'reference_date':
          '${referenceDate.year.toString().padLeft(4, '0')}-${referenceDate.month.toString().padLeft(2, '0')}-${referenceDate.day.toString().padLeft(2, '0')}',
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
    };
    final uri = Uri.parse('$baseUrl/reports/engagement')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return EngagementReport.fromJson(data! as Map<String, dynamic>);
  }

  Future<ActiveStudentsReport> getActiveStudentsReport({
    required DateTime referenceDate,
    required String academyId,
  }) async {
    final params = <String, String>{
      'reference_date':
          '${referenceDate.year.toString().padLeft(4, '0')}-${referenceDate.month.toString().padLeft(2, '0')}-${referenceDate.day.toString().padLeft(2, '0')}',
      'academy_id': academyId,
    };
    final uri = Uri.parse('$baseUrl/reports/active_students')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return ActiveStudentsReport.fromJson(data! as Map<String, dynamic>);
  }

  Future<WeeklyPanelLoginsReport> getWeeklyPanelLoginsReport({
    DateTime? referenceDate,
    DateTime? startDate,
    DateTime? endDate,
    String? academyId,
  }) async {
    final params = <String, String>{
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
    };
    if (startDate != null && endDate != null) {
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      params['start_date'] = ymd(startDate);
      params['end_date'] = ymd(endDate);
    } else {
      final ref = referenceDate ?? DateTime.now();
      params['reference_date'] =
          '${ref.year.toString().padLeft(4, '0')}-${ref.month.toString().padLeft(2, '0')}-${ref.day.toString().padLeft(2, '0')}';
    }
    final uri = Uri.parse('$baseUrl/reports/weekly_panel_logins')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return WeeklyPanelLoginsReport.fromJson(data! as Map<String, dynamic>);
  }

  Future<TechniqueExecutionSummary> getTechniqueExecutionSummary({
    String? academyId,
  }) async {
    final params = <String, String>{
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
    };
    final uri = Uri.parse('$baseUrl/reports/technique_execution_summary')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return TechniqueExecutionSummary.fromJson(data! as Map<String, dynamic>);
  }

  Future<StudentsAttentionReport> getStudentsAttentionReport({
    String? academyId,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
    };
    final uri = Uri.parse('$baseUrl/reports/students_attention')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return StudentsAttentionReport.fromJson(data! as Map<String, dynamic>);
  }

  Future<MissionCompletionReport> getMissionCompletionReport({
    required DateTime fromDate,
    required DateTime toDate,
    String? academyId,
  }) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final params = <String, String>{
      'from_date': ymd(fromDate),
      'to_date': ymd(toDate),
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
    };
    final uri = Uri.parse('$baseUrl/reports/mission_completion')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true, realUserOnly: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionCompletionReport.fromJson(data! as Map<String, dynamic>);
  }

  // ---------- Academy extras (ranking, dificuldades, relatório, reset, missões semanais) ----------

  Future<Map<String, dynamic>> getAcademyRanking(
    String academyId, {
    int periodDays = 30,
    int limit = 50,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final qp = <String, String>{'limit': limit.toString()};
    if (periodStart != null && periodEnd != null) {
      qp['start_date'] = ymd(periodStart);
      qp['end_date'] = ymd(periodEnd);
    } else {
      qp['period_days'] = periodDays.toString();
    }
    final uri = Uri.parse('$baseUrl/academies/$academyId/ranking')
        .replace(queryParameters: qp);
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    if (r.statusCode == 404) return {};
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final entries = (map['entries'] as List<dynamic>?)
            ?.map(
                (e) => AcademyRankingEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return {
      'academy_id': map['academy_id'],
      'period_days': map['period_days'] as int,
      if (map['period_start'] != null)
        'period_start': map['period_start'] as String,
      if (map['period_end'] != null) 'period_end': map['period_end'] as String,
      'entries': entries,
    };
  }

  Future<Map<String, dynamic>> getAcademyDifficulties(
    String academyId, {
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/difficulties')
        .replace(queryParameters: {'limit': limit.toString()});
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    if (r.statusCode == 404) return {};
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final entries = (map['entries'] as List<dynamic>?)
            ?.map((e) =>
                AcademyDifficultyEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return {
      'academy_id': map['academy_id'],
      'entries': entries,
    };
  }

  Future<Map<String, dynamic>> resetAcademyMissions(String academyId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/reset_missions'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Reinicia escolha de turma e progresso na semana ISO atual (calendário horário de Brasília); pontos preservados.
  Future<Map<String, dynamic>> resetAcademyWeeklyTurmasWeek(
      String academyId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/reset_weekly_turmas_week'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/mission_today/week');
    return data! as Map<String, dynamic>;
  }

  Future<AcademyWeeklyReport?> getAcademyWeeklyReport(
    String academyId, {
    int? year,
    int? week,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null && endDate != null) {
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      queryParams['start_date'] = ymd(startDate);
      queryParams['end_date'] = ymd(endDate);
    } else {
      if (year != null) queryParams['year'] = year.toString();
      if (week != null) queryParams['week'] = week.toString();
    }
    final uri = Uri.parse('$baseUrl/academies/$academyId/report/weekly')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    if (r.statusCode == 404) return null;
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return AcademyWeeklyReport.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy?> updateAcademyWeeklyMissions(
    String id, {
    String? weeklyTechniqueId,
    String? weeklyTechnique2Id,
    String? weeklyTechnique3Id,
    int? weeklyMultiplier1,
    int? weeklyMultiplier2,
    int? weeklyMultiplier3,
  }) async {
    final body = <String, dynamic>{
      'weekly_technique_id': weeklyTechniqueId,
      'weekly_technique_2_id': weeklyTechnique2Id,
      'weekly_technique_3_id': weeklyTechnique3Id,
    };
    if (weeklyMultiplier1 != null &&
        weeklyMultiplier1 >= minRewardPoints &&
        weeklyMultiplier1 <= maxRewardPoints) {
      body['weekly_multiplier_1'] = weeklyMultiplier1;
    }
    if (weeklyMultiplier2 != null &&
        weeklyMultiplier2 >= minRewardPoints &&
        weeklyMultiplier2 <= maxRewardPoints) {
      body['weekly_multiplier_2'] = weeklyMultiplier2;
    }
    if (weeklyMultiplier3 != null &&
        weeklyMultiplier3 >= minRewardPoints &&
        weeklyMultiplier3 <= maxRewardPoints) {
      body['weekly_multiplier_3'] = weeklyMultiplier3;
    }
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    if (r.statusCode == 404) return null;
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  // ---------- Professors ----------

  Future<List<Professor>> getProfessors({
    String? academyId,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (academyId != null && academyId.isNotEmpty) {
      params['academy_id'] = academyId;
    }
    final uri = Uri.parse('$baseUrl/professors').replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => Professor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Professor> getProfessor(String id) async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/professors/$id'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Professor.fromJson(data! as Map<String, dynamic>);
  }

  Future<Professor> createProfessor({
    required String name,
    required String email,
    String? academyId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      if (academyId != null) 'academy_id': academyId,
    };
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/professors'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/professors');
    return Professor.fromJson(data! as Map<String, dynamic>);
  }

  Future<Professor> updateProfessor(
    String id, {
    String? name,
    String? email,
    String? academyId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (academyId != null) body['academy_id'] = academyId;
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/professors/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/professors');
    return Professor.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteProfessor(String id) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/professors/$id'),
      headers: await _headers(auth: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/professors');
  }

  // ---------- Training videos (vídeo da tarefa diária / campo de treinamento) ----------
  /// Lista vídeos da tarefa diária disponíveis hoje para o aluno logado.
  /// Endpoint esperado: GET /me/training_videos/today
  Future<List<TrainingVideo>> getTrainingVideosToday({
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset != 0 || limit != 50) {
      return _fetchTrainingVideosTodayBody(offset: offset, limit: limit);
    }
    final existing = _inFlightTrainingVideosToday;
    if (existing != null) return await existing;

    final future = _fetchTrainingVideosTodayBody(offset: offset, limit: limit);
    _inFlightTrainingVideosToday = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightTrainingVideosToday, future)) {
        _inFlightTrainingVideosToday = null;
      }
    }
  }

  Future<List<TrainingVideo>> _fetchTrainingVideosTodayBody({
    required int offset,
    required int limit,
  }) async {
    final uri = Uri.parse('$baseUrl/me/training_videos/today').replace(
      queryParameters: {'offset': '$offset', 'limit': '$limit'},
    );
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => TrainingVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registra a conclusão diária de um vídeo da tarefa diária.
  /// Endpoint esperado: POST /me/training_videos/{id}/complete
  Future<TrainingVideoCompletionResult> completeTrainingVideo(
    String trainingVideoId,
  ) async {
    final uri =
        Uri.parse('$baseUrl/me/training_videos/$trainingVideoId/complete');
    final r = await _req(_client.post(
      uri,
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = (data ?? {}) as Map<String, dynamic>;
    _invalidateHomeHeaderCache();
    return TrainingVideoCompletionResult.fromJson(map);
  }

  /// Lista todos os vídeos da tarefa diária (admin/professor).
  /// Endpoint esperado: GET /training_videos
  Future<List<TrainingVideo>> getTrainingVideosAdmin({
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/training_videos').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => TrainingVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria vídeo da tarefa diária (admin/professor).
  Future<void> createTrainingVideo({
    required String title,
    required String youtubeUrl,
    required int pointsPerDay,
    bool isActive = true,
    required int durationSeconds,
    String? positionDescription,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'youtube_url': youtubeUrl,
      'points_per_day': pointsPerDay,
      'is_active': isActive,
      'duration_seconds': durationSeconds,
    };
    final pd = positionDescription?.trim();
    if (pd != null && pd.isNotEmpty) {
      body['position_description'] = pd;
    }
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/training_videos'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/training_videos');
  }

  /// Atualiza vídeo da tarefa diária (admin/professor).
  Future<void> updateTrainingVideo({
    required String id,
    required String title,
    required String youtubeUrl,
    required int pointsPerDay,
    required bool isActive,
    int? durationSeconds,
    required String positionDescription,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'youtube_url': youtubeUrl,
      'points_per_day': pointsPerDay,
      'is_active': isActive,
    };
    if (durationSeconds != null) {
      body['duration_seconds'] = durationSeconds;
    }
    final pd = positionDescription.trim();
    body['position_description'] = pd.isEmpty ? null : pd;
    final r = await _req(_client.put(
      Uri.parse('$baseUrl/training_videos/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/training_videos');
  }

  /// Remove vídeo da tarefa diária (admin/professor).
  Future<void> deleteTrainingVideo(String id) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/training_videos/$id'),
      headers: await _headers(auth: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/training_videos');
  }

  /// Anúncios ativos da academia do usuário.
  /// Endpoint: GET /me/marketplace_items
  Future<List<MarketplaceItem>> getMeMarketplaceItems({
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/me/marketplace_items').replace(
      queryParameters: {'offset': '$offset', 'limit': '$limit'},
    );
    final r = await _req(_client.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => MarketplaceItem.fromStudentJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lista anúncios (admin: todos; gerente/professor: só da academia).
  /// Endpoint: GET /marketplace_items
  Future<List<MarketplaceItem>> getMarketplaceItemsAdmin({
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/marketplace_items').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw
        .map((e) => MarketplaceItem.fromAdminJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria anúncio. [academyId] obrigatório para administrador global.
  /// [whatsappDdd] e [whatsappNumber] opcionais (ex.: 11 e 999999999).
  Future<void> createMarketplaceItem({
    required String title,
    String? description,
    required int priceCents,
    String currency = 'BRL',
    String? imageUrl,
    String? whatsappDdd,
    String? whatsappNumber,
    int? sortOrder,
    bool isActive = true,
    String? academyId,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'price_cents': priceCents,
      'currency': currency,
      'is_active': isActive,
    };
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['image_url'] = imageUrl;
    }
    final ddd = whatsappDdd?.trim();
    final num = whatsappNumber?.trim();
    if (ddd != null && ddd.isNotEmpty) {
      body['whatsapp_ddd'] = ddd;
    }
    if (num != null && num.isNotEmpty) {
      body['whatsapp_number'] = num;
    }
    if (sortOrder != null) {
      body['sort_order'] = sortOrder;
    }
    if (academyId != null && academyId.isNotEmpty) {
      body['academy_id'] = academyId;
    }
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/marketplace_items'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/marketplace_items');
  }

  Future<void> updateMarketplaceItem({
    required String id,
    required String title,
    String? description,
    required int priceCents,
    String currency = 'BRL',
    String? imageUrl,
    String? whatsappDdd,
    String? whatsappNumber,
    int? sortOrder,
    required bool isActive,
  }) async {
    final dddW = whatsappDdd?.trim();
    final numW = whatsappNumber?.trim();
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'price_cents': priceCents,
      'currency': currency,
      'whatsapp_ddd': (dddW == null || dddW.isEmpty) ? null : dddW,
      'whatsapp_number': (numW == null || numW.isEmpty) ? null : numW,
      'is_active': isActive,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['image_url'] = imageUrl;
    } else {
      body['image_url'] = null;
    }
    body['sort_order'] = sortOrder;
    final r = await _req(_client.put(
      Uri.parse('$baseUrl/marketplace_items/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/marketplace_items');
  }

  Future<void> deleteMarketplaceItem(String id) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/marketplace_items/$id'),
      headers: await _headers(auth: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/marketplace_items');
  }

  /// Faz upload de imagem para anúncio e retorna a URL `/media/marketplace/...`.
  Future<String> uploadMarketplaceImage({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final safeFilename =
        filename.trim().isEmpty ? 'product.jpg' : filename.trim();
    final uri = Uri.parse('$baseUrl/marketplace_items/upload_image');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: safeFilename,
        contentType:
            _mediaTypeFromContentTypeOrFilename(contentType, safeFilename, bytes),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return (data as Map<String, dynamic>)['image_url'] as String;
  }

  /// Registra clique no botão "Chamar no WhatsApp" de um anúncio.
  Future<void> recordMarketplaceWhatsappClick(String itemId) async {
    try {
      await _req(_client.post(
        Uri.parse('$baseUrl/me/marketplace_items/$itemId/whatsapp_click'),
        headers: await _headers(auth: true),
      ));
    } catch (_) {
      // Melhor esforço — não bloqueia a abertura do WhatsApp
    }
  }

  static const _backupDownloadTimeout = Duration(minutes: 10);

  /// Alinhar com BACKUP_PSQL_RESTORE_TIMEOUT_SEC (até 2h) + upload de ZIP grande.
  static const _restoreBackupTimeout = Duration(hours: 2, minutes: 15);

  /// Dump SQL completo do PostgreSQL (apenas administrador).
  /// Sem impersonação no header (necessário durante "Atuar como").
  Future<Uint8List> downloadDatabaseBackup() async {
    final uri = Uri.parse('$baseUrl/admin/backup/database');
    final r = await http
        .get(uri, headers: await _headers(auth: true, realUserOnly: true))
        .timeout(_backupDownloadTimeout);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.bodyBytes;
    }
    dynamic data;
    try {
      if (r.body.isNotEmpty) {
        data = jsonDecode(r.body);
      }
    } catch (_) {
      data = null;
    }
    _throwIfNotOk(r, data);
    throw ApiException(r.statusCode, r.reasonPhrase ?? 'Erro ao baixar backup');
  }

  /// ZIP com database.sql + pasta media/ (logos, horários).
  Future<Uint8List> downloadBackupArchive() async {
    final uri = Uri.parse('$baseUrl/admin/backup/archive');
    final r = await http
        .get(uri, headers: await _headers(auth: true, realUserOnly: true))
        .timeout(_backupDownloadTimeout);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.bodyBytes;
    }
    dynamic data;
    try {
      if (r.body.isNotEmpty) {
        data = jsonDecode(r.body);
      }
    } catch (_) {
      data = null;
    }
    _throwIfNotOk(r, data);
    throw ApiException(
        r.statusCode, r.reasonPhrase ?? 'Erro ao baixar arquivo ZIP');
  }

  /// Restaura banco (destrutivo) e opcionalmente mídia. Web: [bytes]; nativo: [filePath] ou [bytes].
  ///
  /// O timeout cobre envio do ZIP + tempo do `psql` no servidor (pode demorar muito).
  Future<Map<String, dynamic>> restoreBackupZip({
    List<int>? bytes,
    String? filePath,
    required String filename,
  }) {
    final minutes = _restoreBackupTimeout.inMinutes;
    return Future(() async {
      final uri = Uri.parse('$baseUrl/admin/backup/restore');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _headers(auth: true, realUserOnly: true));
      await backup_multipart.attachRestoreZip(
        request,
        bytes: bytes,
        path: filePath,
        filename: filename,
      );
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        invalidateCache();
        if (response.body.isEmpty) {
          return <String, dynamic>{
            'ok': true,
            'restored_media': null,
            'note': 'Resposta vazia; confirme login e dados após recarregar.',
          };
        }
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          throw ApiException(
            response.statusCode,
            'A API devolveu uma resposta que não é JSON após a restauração. '
            'Reinicie a API (docker compose restart api), recarregue a página e faça login.',
          );
        }
        if (decoded is! Map) {
          throw ApiException(
              response.statusCode, 'Resposta inesperada após restauração.');
        }
        return Map<String, dynamic>.from(decoded);
      }
      dynamic data;
      try {
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body);
        }
      } catch (_) {
        data = null;
      }
      if (response.body.isEmpty && response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          'Resposta vazia do servidor (a API pode ter reiniciado ou caído durante o restore). '
          'Aguarde 1–2 min, execute docker compose restart api e tente de novo.',
        );
      }
      _throwIfNotOk(response, data);
      throw ApiException(
          response.statusCode, response.reasonPhrase ?? 'Erro na restauração');
    }).timeout(
      _restoreBackupTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Tempo esgotado após $minutes minutos. O servidor pode ainda estar restaurando bancos grandes. '
          'Aguarde 2–5 minutos, reinicie a API (docker compose restart api), recarregue a página e tente entrar. '
          'Consulte os logs: docker compose logs api',
          _restoreBackupTimeout,
        );
      },
    );
  }

  // ---------- Notificações in-app ----------

  Future<List<Map<String, dynamic>>> getNotifications({
    int offset = 0,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
      'offset': '$offset',
      'limit': '$limit',
      if (unreadOnly) 'unread_only': 'true',
    });
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<int> getUnreadNotificationsCount() async {
    final r = await _req(
      _client.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: await _headers(auth: true),
      ),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data is Map ? data as Map<String, dynamic> : null;
    return (map?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<void> markAllNotificationsRead() async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/notifications/$notificationId'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  // ---------- OctoPhotos ----------

  Future<PhotoFeedPage> getPhotosFeed(
    String academyId, {
    String? cursor,
    int limit = 20,
    String? authorId,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = cursor;
    if (authorId != null) params['author_id'] = authorId;
    final uri = Uri.parse('$baseUrl/academies/$academyId/photos')
        .replace(queryParameters: params);
    final r = await _getWithCache(uri, 0);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return PhotoFeedPage.fromJson(data! as Map<String, dynamic>);
  }

  Future<AcademyPhoto> createPhoto(
    String academyId, {
    required List<int> bytes,
    required String filename,
    required MediaType contentType,
    String? caption,
  }) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/photos');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(auth: true));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      ),
    );
    if (caption != null && caption.isNotEmpty) {
      request.fields['caption'] = caption;
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return AcademyPhoto.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> likePhoto(String academyId, String photoId) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/photos/$photoId/like'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<void> unlikePhoto(String academyId, String photoId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/academies/$academyId/photos/$photoId/like'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<void> deletePhoto(String academyId, String photoId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/academies/$academyId/photos/$photoId'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204 && r.statusCode >= 400) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<List<PhotoRestriction>> getPhotoRestrictions(
      String academyId) async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/academies/$academyId/photos/restrictions'),
      0,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data! as List<dynamic>)
        .map((e) => PhotoRestriction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhotoRestriction> createPhotoRestriction(
    String academyId,
    String userId, {
    String? reason,
    DateTime? expiresAt,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/photos/restrictions'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({
        'user_id': userId,
        if (reason != null) 'reason': reason,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return PhotoRestriction.fromJson(data! as Map<String, dynamic>);
  }

  Future<PhotoRestriction> patchPhotoRestriction(
    String academyId,
    String restrictionId, {
    bool? active,
    String? reason,
    DateTime? expiresAt,
  }) async {
    final body = <String, dynamic>{};
    if (active != null) body['active'] = active;
    if (reason != null) body['reason'] = reason;
    if (expiresAt != null) body['expires_at'] = expiresAt.toIso8601String();
    final r = await _req(_client.patch(
      Uri.parse(
          '$baseUrl/academies/$academyId/photos/restrictions/$restrictionId'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return PhotoRestriction.fromJson(data! as Map<String, dynamic>);
  }

  Future<List<PhotoComment>> listComments(
      String academyId, String photoId) async {
    final r = await _getWithCache(
      Uri.parse('$baseUrl/academies/$academyId/photos/$photoId/comments'),
      0,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data! as List<dynamic>;
    return list
        .map((e) => PhotoComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhotoComment> addComment(
      String academyId, String photoId, String body) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/academies/$academyId/photos/$photoId/comments'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'body': body}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return PhotoComment.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteComment(
      String academyId, String photoId, String commentId) async {
    final r = await _req(_client.delete(
      Uri.parse(
          '$baseUrl/academies/$academyId/photos/$photoId/comments/$commentId'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  Future<List<Map<String, dynamic>>> getMentionSuggestions(
      String academyId, String q) async {
    final r = await _req(_client.get(
      Uri.parse(
          '$baseUrl/academies/$academyId/photos/mention-suggestions?q=${Uri.encodeQueryComponent(q)}'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data! as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<AcademyPhoto?> getPhotoById(
      String academyId, String photoId) async {
    try {
      final r = await _req(_client.get(
        Uri.parse('$baseUrl/academies/$academyId/photos/$photoId'),
        headers: await _headers(auth: true),
      ));
      if (r.statusCode == 404) return null;
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
      return AcademyPhoto.fromJson(data! as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ---------- Enrollment Invite ----------

  Future<Map<String, dynamic>> getEnrollmentInvite(String academyId) async {
    final r = await _req(
      _client.get(
        Uri.parse('$baseUrl/academies/$academyId/enrollment-invite'),
        headers: await _headers(auth: true),
      ),
    );
    return await _decodeResponse(r);
  }

  Future<Map<String, dynamic>> rotateEnrollmentInvite(String academyId) async {
    final r = await _req(
      _client.post(
        Uri.parse('$baseUrl/academies/$academyId/enrollment-invite/rotate'),
        headers: await _jsonHeaders(auth: true),
        body: '{}',
      ),
    );
    return await _decodeResponse(r);
  }

  Future<List<Map<String, dynamic>>> getPendingEnrollments(
    String academyId, {
    String status = 'pending',
  }) async {
    final r = await _req(
      _client.get(
        Uri.parse(
            '$baseUrl/academies/$academyId/pending-enrollments?status=$status'),
        headers: await _headers(auth: true),
      ),
    );
    final data = await _decodeResponse(r);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> decideEnrollment(
    String academyId,
    String enrollmentId, {
    required String action,
    String? rejectionReason,
  }) async {
    final r = await _req(
      _client.post(
        Uri.parse(
            '$baseUrl/academies/$academyId/pending-enrollments/$enrollmentId/decide'),
        headers: await _jsonHeaders(auth: true),
        body: jsonEncode({
          'action': action,
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
        }),
      ),
    );
    return await _decodeResponse(r);
  }

  /// Público — sem autenticação.
  Future<Map<String, dynamic>> getInvitePublicInfo(String token) async {
    final r = await _req(
      _client.get(Uri.parse('$baseUrl/register/$token')),
    );
    return await _decodeResponse(r);
  }

  /// Público — envia formulário de cadastro.
  Future<String> submitEnrollment(
    String token, {
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    String? phone,
    String? graduation,
  }) async {
    final r = await _req(
      _client.post(
        Uri.parse('$baseUrl/register/$token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (graduation != null && graduation.isNotEmpty)
            'graduation': graduation,
        }),
      ),
    );
    final data = await _decodeResponse(r);
    return data['message'] as String;
  }

  // -------------------------------------------------------------------------
  // Privacidade / LGPD (direitos do titular)
  // -------------------------------------------------------------------------

  /// URL pública (HTML) de um documento legal: 'privacy' | 'terms' | 'biometric'.
  String legalDocumentViewUrl(String slug) => '$baseUrl/legal/$slug/view';

  /// Estado vigente dos consentimentos do utilizador autenticado.
  Future<List<Map<String, dynamic>>> getMyConsents() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/me/consents'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return (map['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Registra a concessão (ou revogação) de um consentimento.
  Future<void> recordConsent({
    required String consentType,
    bool granted = true,
    String? documentVersion,
  }) async {
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/me/consents'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({
        'consent_type': consentType,
        'granted': granted,
        if (documentVersion != null) 'document_version': documentVersion,
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  /// Revoga o consentimento biométrico e apaga embedding + foto facial.
  Future<void> revokeBiometricConsent() async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/me/consents/biometric'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  /// Baixa uma cópia dos dados pessoais do titular (direito de acesso/portabilidade).
  Future<Map<String, dynamic>> exportMyData() async {
    final r = await _req(_client.get(
      Uri.parse('$baseUrl/me/data-export'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Solicita a eliminação (anonimização) da conta do titular. Irreversível.
  Future<void> deleteMyAccount() async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/me/account'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  // -------------------------------------------------------------------------
  // Troféus Manuais
  // -------------------------------------------------------------------------

  /// Lista templates de troféus da academia.
  Future<List<Map<String, dynamic>>> getManualTrophyTemplates(
    String academyId, {
    String? trophyType,
  }) async {
    final params = <String, String>{'academy_id': academyId};
    if (trophyType != null) params['trophy_type'] = trophyType;
    final uri = Uri.parse('$baseUrl/manual-trophies/templates')
        .replace(queryParameters: params);
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Cria template de troféu.
  Future<Map<String, dynamic>> createManualTrophyTemplate({
    required String academyId,
    required String name,
    String? description,
    String? icon,
    String? color,
    String trophyType = 'custom',
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
      'trophy_type': trophyType,
      if (description != null && description.isNotEmpty) 'description': description,
      if (icon != null && icon.isNotEmpty) 'icon': icon,
      if (color != null && color.isNotEmpty) 'color': color,
    };
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/manual-trophies/templates'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/manual-trophies/templates');
    return data! as Map<String, dynamic>;
  }

  /// Atualiza template de troféu.
  Future<Map<String, dynamic>> updateManualTrophyTemplate(
    String templateId, {
    String? name,
    String? description,
    String? icon,
    String? color,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description.isEmpty ? null : description;
    if (icon != null) body['icon'] = icon.isEmpty ? null : icon;
    if (color != null) body['color'] = color.isEmpty ? null : color;
    final r = await _req(_client.patch(
      Uri.parse('$baseUrl/manual-trophies/templates/${Uri.encodeComponent(templateId)}'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/manual-trophies/templates');
    return data! as Map<String, dynamic>;
  }

  /// Remove template (soft delete).
  Future<void> deleteManualTrophyTemplate(String templateId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/manual-trophies/templates/${Uri.encodeComponent(templateId)}'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
    invalidateCache('GET:$baseUrl/manual-trophies/templates');
  }

  /// Lista campeonatos da academia.
  Future<List<Map<String, dynamic>>> getChampionshipEvents(String academyId) async {
    final uri = Uri.parse('$baseUrl/manual-trophies/championships')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(
      _client.get(uri, headers: await _headers(auth: true)),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Cria campeonato.
  Future<Map<String, dynamic>> createChampionshipEvent({
    required String academyId,
    required String name,
    required String eventDate,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
      'event_date': eventDate,
      if (location != null && location.isNotEmpty) 'location': location,
    };
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/manual-trophies/championships'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/manual-trophies/championships');
    return data! as Map<String, dynamic>;
  }

  /// Remove campeonato (soft delete).
  Future<void> deleteChampionshipEvent(String eventId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/manual-trophies/championships/${Uri.encodeComponent(eventId)}'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
    invalidateCache('GET:$baseUrl/manual-trophies/championships');
  }

  /// Concede troféu/medalha a um aluno.
  Future<Map<String, dynamic>> awardManualTrophy({
    required String templateId,
    required String userId,
    String? championshipEventId,
    String? medalType,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'template_id': templateId,
      'user_id': userId,
      if (championshipEventId != null) 'championship_event_id': championshipEventId,
      if (medalType != null) 'medal_type': medalType,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final r = await _req(_client.post(
      Uri.parse('$baseUrl/manual-trophies/awards'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Remove concessão de troféu.
  Future<void> revokeManualTrophyAward(String awardId) async {
    final r = await _req(_client.delete(
      Uri.parse('$baseUrl/manual-trophies/awards/${Uri.encodeComponent(awardId)}'),
      headers: await _headers(auth: true),
    ));
    if (r.statusCode != 204) {
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
    }
  }

  /// Concessões de um aluno agrupadas por tipo.
  Future<Map<String, dynamic>> getUserManualTrophyAwards(String userId) async {
    final r = await _req(
      _client.get(
        Uri.parse('$baseUrl/manual-trophies/awards/user/${Uri.encodeComponent(userId)}'),
        headers: await _headers(auth: true),
      ),
      timeout: _getTimeout,
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Lista alunos da academia para seleção — pagina até buscar todos (limit máx 50).
  Future<List<Map<String, dynamic>>> getAcademyStudentsForSelection(
    String academyId,
  ) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    const pageSize = 50;
    while (true) {
      final uri = Uri.parse('$baseUrl/users').replace(queryParameters: {
        'academy_id': academyId,
        'limit': '$pageSize',
        'offset': '$offset',
      });
      final r = await _req(
        _client.get(uri, headers: await _headers(auth: true)),
        timeout: _getTimeout,
      );
      final data = await _decodeResponse(r);
      _throwIfNotOk(r, data);
      final page = (data as List<dynamic>).cast<Map<String, dynamic>>();
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  /// Quiosque facial: envia frame e recebe resultado de check-in em tempo real.
  Future<FaceArriveResponse> faceArrive(
    String sessionId,
    Uint8List frame,
  ) async {
    final uri = Uri.parse('$baseUrl/attendance/sessions/$sessionId/face-arrive');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'frame',
        frame,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return FaceArriveResponse.fromJson(data! as Map<String, dynamic>);
  }

}
