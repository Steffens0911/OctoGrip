import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:viewer/config.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/active_students_report.dart';
import 'package:viewer/models/engagement_report.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/models/professor.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/trophy.dart';
import 'package:viewer/models/training_video.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'dart:typed_data';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Cache in-memory com TTL para reduzir requisições repetidas (troca de telas, abas).
class _CacheEntry {
  final String body;
  final int statusCode;
  final int expiresAtMs;
  _CacheEntry(this.body, this.statusCode, this.expiresAtMs);
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  late final String baseUrl;
  static const _timeout = Duration(seconds: 15);

  final Map<String, _CacheEntry> _getCache = {};
  static const int _cacheTtlShort = 30; // mission_today, week, pending count
  static const int _cacheTtlMedium = 60; // listas: academies, lessons, techniques, users

  ApiService._() {
    baseUrl = kApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  String _cacheKey(String method, Uri uri) => '$method:${uri.toString()}';

  String? _getCached(String key, int ttlSeconds) {
    final entry = _getCache[key];
    if (entry == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > entry.expiresAtMs) {
      _getCache.remove(key);
      return null;
    }
    return entry.statusCode >= 200 && entry.statusCode < 300 ? entry.body : null;
  }

  void _setCache(String key, String body, int statusCode, int ttlSeconds) {
    if (statusCode < 200 || statusCode >= 300) return;
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + (ttlSeconds * 1000);
    _getCache[key] = _CacheEntry(body, statusCode, expiresAtMs);
  }

  /// Invalida cache por prefixo (ex: "GET:$baseUrl/academies") ou todo o cache.
  void invalidateCache([String? prefix]) {
    if (prefix == null || prefix.isEmpty) {
      _getCache.clear();
      return;
    }
    _getCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  Future<http.Response> _req(Future<http.Response> f) => f.timeout(_timeout);

  /// GET com cache. [ttlSeconds] 0 = sem cache. Retorna body (string); em cache hit não chama a rede.
  Future<http.Response> _getWithCache(Uri uri, int ttlSeconds) async {
    final key = _cacheKey('GET', uri);
    if (ttlSeconds > 0) {
      final cached = _getCached(key, ttlSeconds);
      if (cached != null) {
        return http.Response(cached, 200, headers: {'content-type': 'application/json'});
      }
    }
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    if (ttlSeconds > 0 && r.statusCode >= 200 && r.statusCode < 300) {
      _setCache(key, r.body, r.statusCode, ttlSeconds);
    }
    return r;
  }

  /// Garante que o token foi carregado do storage (importante no web após refresh).
  Future<void> _ensureAuth() async => await AuthService().ensureLoaded();

  /// [realUserOnly] true = não envia X-Impersonate-User (para o admin conseguir listar usuários e voltar da simulação).
  Future<Map<String, String>> _headers({bool auth = false, bool realUserOnly = false}) async {
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

  Future<Map<String, String>> _jsonHeaders({bool auth = false, bool realUserOnly = false}) async {
    final h = await _headers(auth: auth, realUserOnly: realUserOnly);
    h['Content-Type'] = 'application/json';
    return h;
  }

  // ---------- Auth ----------
  /// Login. Retorna (token, user). Lança ApiException em erro.
  Future<({String token, UserModel user})> login(String email, String password) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final token = map['access_token'] as String;
    final user = await getAuthMe(token);
    return (token: token, user: user);
  }

  /// Retorna o usuário logado (requer token).
  Future<UserModel> getAuthMe([String? token]) async {
    final h = token != null
        ? <String, String>{'Authorization': 'Bearer $token'}
        : await _jsonHeaders(auth: true);
    final r = await _req(http.get(Uri.parse('$baseUrl/auth/me'), headers: h));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza preferência "galeria visível para outros" do usuário autenticado.
  Future<UserModel> patchMeGalleryVisible(bool visible) async {
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'gallery_visible': visible}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<dynamic> _decodeResponse(http.Response r) async {
    final body = r.body;
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }

  void _throwIfNotOk(http.Response r, [dynamic data]) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 401) {
      AuthService().logout(notifyInvalidated: true);
    }
    String msg = r.reasonPhrase ?? 'Erro ${r.statusCode}';
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      msg = d is String ? d : d.toString();
    }
    if (r.statusCode == 404) {
      msg = 'Não encontrado (404). Verifique se a API está rodando em $baseUrl';
    }
    throw ApiException(r.statusCode, msg);
  }

  // ---------- Academies ----------
  Future<List<Academy>> getAcademies() async {
    final r = await _getWithCache(Uri.parse('$baseUrl/academies'), _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Academy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Academy> getAcademy(String id) async {
    final r = await _getWithCache(Uri.parse('$baseUrl/academies/$id'), _cacheTtlMedium);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Retorna a academia sem usar cache (para o brasão na home do aluno aparecer logo após o admin salvar).
  Future<Academy> getAcademyFresh(String id) async {
    final r = await _req(http.get(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Resolve URL de horários: se for post do Instagram, retorna thumbnail para exibição; senão retorna a própria URL.
  /// Retorna { display_url: String?, original_url: String? }.
  Future<Map<String, dynamic>> getScheduleDisplayUrl(String scheduleUrl) async {
    final uri = Uri.parse('$baseUrl/academies/schedule_display_url').replace(
      queryParameters: {'url': scheduleUrl},
    );
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return {
      'display_url': map['display_url'] as String?,
      'original_url': map['original_url'] as String?,
    };
  }

  Future<Map<String, dynamic>?> getCollectiveGoalCurrent(String academyId) async {
    final r = await _getWithCache(Uri.parse('$baseUrl/academies/$academyId/collective_goals/current'), _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Academy> createAcademy({required String name, String? slug}) async {
    final r = await _req(http.post(
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
    final r = await _req(http.patch(
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
          if (offset + i >= bytes.length || (bytes[offset + i] & 0xff) != magic[i]) return false;
        }
        return true;
      }
      if (match(_pngMagic, 0)) return 'png';
      if (bytes.length >= 2 && match(_jpegMagic, 0)) return 'jpg';
      if (bytes.length >= 12 && match(_webpMagic, 0) && match(_webpFourcc, 8)) return 'webp';
    }
    return 'png';
  }

  Future<Academy> uploadAcademyLogo(String id, Uint8List bytes, String filename) async {
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
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy> uploadAcademyScheduleImage(String id, Uint8List bytes, String filename) async {
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
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = await _decodeResponse(response);
    _throwIfNotOk(response, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
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
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (weeklyTheme != null) body['weekly_theme'] = weeklyTheme;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (scheduleImageUrl != null) body['schedule_image_url'] = scheduleImageUrl;
    if (weeklyTechniqueId != null) body['weekly_technique_id'] = weeklyTechniqueId;
    if (updateVisibleLesson) body['visible_lesson_id'] = visibleLessonId;
    if (showTrophies != null) body['show_trophies'] = showTrophies;
    if (showPartners != null) body['show_partners'] = showPartners;
    if (showSchedule != null) body['show_schedule'] = showSchedule;
    if (showGlobalSupporters != null) {
      body['show_global_supporters'] = showGlobalSupporters;
    }
    if (body.isEmpty) return getAcademy(id);
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteAcademy(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/academies/$id'), headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/academies');
  }

  // ---------- Users ----------
  /// [asRealUser] true = não envia impersonation (para o seletor "Atuar como" carregar como admin e permitir voltar).
  Future<List<UserModel>> getUsers({String? academyId, bool asRealUser = false, int offset = 0, int limit = 50}) async {
    var queryParams = <String, String>{};
    if (academyId != null && academyId.isNotEmpty) {
      queryParams['academy_id'] = academyId;
    }
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    if (limit != 50) {
      queryParams['limit'] = limit.toString();
    }
    var uri = Uri.parse('$baseUrl/users');
    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final r = asRealUser
        ? await _req(http.get(uri, headers: await _headers(auth: true, realUserOnly: true)))
        : await _getWithCache(uri, _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getUserPoints(String userId) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/users/$userId/points'), headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Pontos de todos os usuários da academia em uma requisição (evita N+1 na tela de pontos).
  Future<Map<String, int>> getAcademyUserPoints(String academyId) async {
    final r = await _req(http.get(
      Uri.parse('$baseUrl/academies/$academyId/user_points'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final byUser = map['points_by_user'] as Map<String, dynamic>? ?? {};
    return byUser.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<Map<String, dynamic>> getPointsLog(String userId, {int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/users/$userId/points_log').replace(queryParameters: {'limit': limit.toString()});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Galeria de troféus do usuário (troféus da academia com tier conquistado).
  Future<List<TrophyWithEarned>> getTrophiesForUser(String userId) async {
    final r = await _req(http.get(
      Uri.parse('$baseUrl/trophies/user/$userId'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => TrophyWithEarned.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lista troféus da academia (admin).
  Future<List<Map<String, dynamic>>> getTrophies(String academyId) async {
    final uri = Uri.parse('$baseUrl/trophies').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
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
    int minPointsToUnlock = 0,
    String? minGraduationToUnlock,
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
    if (minPointsToUnlock != 0) body['min_points_to_unlock'] = minPointsToUnlock;
    if (minGraduationToUnlock != null && minGraduationToUnlock.isNotEmpty) body['min_graduation_to_unlock'] = minGraduationToUnlock;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/trophies'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  /// Lista parceiros da academia (alunos: sem academy_id usa a do usuário; gestor/admin: academy_id obrigatório para admin).
  Future<List<Partner>> getPartners([String? academyId]) async {
    final queryParams = academyId != null && academyId.isNotEmpty ? {'academy_id': academyId} : null;
    final uri = Uri.parse('$baseUrl/partners').replace(queryParameters: queryParams);
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final raw = data is List ? data : <dynamic>[];
    return raw.map((e) => Partner.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cria parceiro na academia.
  Future<Partner> createPartner({
    required String academyId,
    required String name,
    String? description,
    String? url,
    String? logoUrl,
    bool highlightOnLogin = false,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
    };
    if (description != null && description.isNotEmpty) body['description'] = description;
    if (url != null && url.isNotEmpty) body['url'] = url;
    if (logoUrl != null && logoUrl.isNotEmpty) body['logo_url'] = logoUrl;
     body['highlight_on_login'] = highlightOnLogin;
    final r = await _req(http.post(
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
    bool? highlightOnLogin,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (url != null) body['url'] = url;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (highlightOnLogin != null) body['highlight_on_login'] = highlightOnLogin;
    final uri = Uri.parse('$baseUrl/partners/$partnerId').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.put(uri, headers: await _jsonHeaders(auth: true), body: jsonEncode(body)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/partners');
    return Partner.fromJson(data! as Map<String, dynamic>);
  }

  /// Remove parceiro.
  Future<void> deletePartner(String partnerId, String academyId) async {
    final uri = Uri.parse('$baseUrl/partners/$partnerId').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/partners');
  }

  Future<UserModel> getUser(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/users/$id'), headers: await _headers(auth: true)));
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
    final r = await _req(http.post(
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

  Future<UserModel> updateUser(String id, {String? name, String? graduation, String? role, String? password, String? academyId, int? pointsAdjustment}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (graduation != null) body['graduation'] = graduation;
    if (role != null) body['role'] = role;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (academyId != null) body['academy_id'] = academyId;
    if (pointsAdjustment != null) body['points_adjustment'] = pointsAdjustment;
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/users/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/users');
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/users/$id'), headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    // Limpar cache de listagem de usuários após exclusão.
    invalidateCache('GET:$baseUrl/users');
  }

  // ---------- Lessons ----------
  /// Lista lições. Se [academyId] for informado e a academia tiver lição visível, retorna só ela.
  Future<List<Lesson>> getLessons({String? academyId, int offset = 0, int limit = 100}) async {
    var queryParams = <String, String>{};
    if (academyId != null) {
      queryParams['academy_id'] = academyId;
    }
    if (offset > 0) {
      queryParams['offset'] = offset.toString();
    }
    if (limit != 100) {
      queryParams['limit'] = limit.toString();
    }
    final uri = queryParams.isNotEmpty
        ? Uri.parse('$baseUrl/lessons').replace(queryParameters: queryParams)
        : Uri.parse('$baseUrl/lessons');
    final r = await _getWithCache(uri, _cacheTtlMedium);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Lesson> getLesson(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/lessons/$id'), headers: await _headers(auth: true)));
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
    final r = await _req(http.post(
      Uri.parse('$baseUrl/lessons'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
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
    final r = await _req(http.put(
      Uri.parse('$baseUrl/lessons/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteLesson(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/lessons/$id'), headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Techniques ----------
  /// Lista técnicas da academia. [academyId] obrigatório. Sem cache para refletir CRUD na hora.
  Future<List<Technique>> getTechniques({required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques').replace(queryParameters: {'academy_id': academyId});
    final r = await _getWithCache(uri, 0);
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Technique.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Technique> getTechnique(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
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
    final r = await _req(http.post(
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
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.put(
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
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.delete(uri, headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/techniques');
  }

  // ---------- Missions ----------
  Future<List<Mission>> getMissions() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/missions'), headers: await _headers(auth: true)));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Mission.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Mission> getMission(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/missions/$id'), headers: await _headers(auth: true)));
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
    int multiplier = 1,
  }) async {
    final r = await _req(http.post(
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
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/missions/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Mission.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteMission(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/missions/$id'), headers: await _headers(auth: true)));
    _throwIfNotOk(r, await _decodeResponse(r));
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

  /// Lista das 3 missões da semana (Seg–Ter, Qua–Qui, Sex–Dom) para exibição ao aluno.
  /// [level] mapeado da faixa do usuário: beginner (white/blue) ou intermediate (purple/brown/black).
  Future<MissionWeek> getMissionWeek({
    String level = 'beginner',
    String? academyId,
  }) async {
    final params = <String, String>{
      'level': level,
      if (academyId != null) 'academy_id': academyId,
    };
    var uri = Uri.parse('$baseUrl/mission_today/week').replace(queryParameters: params);
    final r = await _getWithCache(uri, _cacheTtlShort);
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionWeek.fromJson(data! as Map<String, dynamic>);
  }

  /// Indica se a lição já foi concluída pelo usuário logado (para botão desabilitado ao abrir).
  Future<bool> getLessonCompleteStatus({required String lessonId}) async {
    final uri = Uri.parse('$baseUrl/lesson_complete/status').replace(queryParameters: {'lesson_id': lessonId});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return map['completed'] as bool? ?? false;
  }

  Future<void> postLessonComplete({required String lessonId}) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/lesson_complete'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'lesson_id': lessonId}),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/mission_today');
    invalidateCache('GET:$baseUrl/executions');
  }

  /// Conclusão por missão (missão do dia). usageType: before_training | after_training.
  Future<void> postMissionComplete({
    required String missionId,
    String usageType = 'after_training',
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/mission_complete'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode({'mission_id': missionId, 'usage_type': usageType}),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
    invalidateCache('GET:$baseUrl/mission_today');
    invalidateCache('GET:$baseUrl/executions');
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
    final r = await _req(http.post(
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

  Future<List<Map<String, dynamic>>> getPendingConfirmations() async {
    final r = await _req(http.get(
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
    final r = await _req(http.post(
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
    final r = await _req(http.post(
      Uri.parse('$baseUrl/executions/$executionId/reject'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    invalidateCache('GET:$baseUrl/executions');
    return data! as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyExecutions() async {
    final r = await _req(http.get(
      Uri.parse('$baseUrl/executions/my_executions'),
      headers: await _headers(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<MissionHistoryItem>> getMissionUsagesHistory({int limit = 7}) async {
    final uri = Uri.parse('$baseUrl/mission_usages/history').replace(queryParameters: {'limit': limit.toString()});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final list = map['missions'] as List<dynamic>? ?? [];
    return list.map((e) => MissionHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> postTrainingFeedback({
    String? observation,
  }) async {
    final body = <String, dynamic>{};
    if (observation != null && observation.isNotEmpty) body['observation'] = observation;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/training_feedback'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  Future<UsageMetrics> getMetricsUsage() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/metrics/usage')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UsageMetrics.fromJson(data! as Map<String, dynamic>);
  }

  Future<UsageMetrics> getMetricsUsageForAcademy(String academyId) async {
    final uri = Uri.parse('$baseUrl/metrics/usage/by_academy')
        .replace(queryParameters: {'academy_id': academyId});
    final r = await _req(
      http.get(uri, headers: await _headers(auth: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UsageMetrics.fromJson(data! as Map<String, dynamic>);
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
      http.get(uri, headers: await _headers(auth: true)),
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
      http.get(uri, headers: await _headers(auth: true)),
    );
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return ActiveStudentsReport.fromJson(data! as Map<String, dynamic>);
  }

  // ---------- Academy extras (ranking, dificuldades, relatório, reset, missões semanais) ----------

  Future<Map<String, dynamic>> getAcademyRanking(
    String academyId, {
    int periodDays = 30,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/ranking')
        .replace(queryParameters: {
      'period_days': periodDays.toString(),
      'limit': limit.toString(),
    });
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    if (r.statusCode == 404) return {};
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final entries = (map['entries'] as List<dynamic>?)
            ?.map((e) =>
                AcademyRankingEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return {
      'academy_id': map['academy_id'],
      'period_days': map['period_days'] as int,
      'entries': entries,
    };
  }

  Future<Map<String, dynamic>> getAcademyDifficulties(
    String academyId, {
    int limit = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/academies/$academyId/difficulties')
        .replace(queryParameters: {'limit': limit.toString()});
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
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
    final r = await _req(http.post(
      Uri.parse('$baseUrl/academies/$academyId/reset_missions'),
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<AcademyWeeklyReport?> getAcademyWeeklyReport(
    String academyId, {
    int? year,
    int? week,
  }) async {
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (week != null) queryParams['week'] = week.toString();
    final uri = Uri.parse('$baseUrl/academies/$academyId/report/weekly')
        .replace(
            queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
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
    if (weeklyMultiplier1 != null && weeklyMultiplier1 >= 1) {
      body['weekly_multiplier_1'] = weeklyMultiplier1;
    }
    if (weeklyMultiplier2 != null && weeklyMultiplier2 >= 1) {
      body['weekly_multiplier_2'] = weeklyMultiplier2;
    }
    if (weeklyMultiplier3 != null && weeklyMultiplier3 >= 1) {
      body['weekly_multiplier_3'] = weeklyMultiplier3;
    }
    final r = await _req(http.patch(
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

  Future<List<Professor>> getProfessors({String? academyId}) async {
    var uri = Uri.parse('$baseUrl/professors');
    if (academyId != null && academyId.isNotEmpty) {
      uri = uri.replace(queryParameters: {'academy_id': academyId});
    }
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw
        .map((e) => Professor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Professor> getProfessor(String id) async {
    final r = await _req(http.get(
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
    final r = await _req(http.post(
      Uri.parse('$baseUrl/professors'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
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
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/professors/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Professor.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteProfessor(String id) async {
    final r = await _req(http.delete(
      Uri.parse('$baseUrl/professors/$id'),
      headers: await _headers(auth: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Training videos (campo de treinamento) ----------
  /// Lista vídeos de treinamento disponíveis hoje para o aluno logado.
  /// Endpoint esperado: GET /me/training_videos/today
  Future<List<TrainingVideo>> getTrainingVideosToday() async {
    final uri = Uri.parse('$baseUrl/me/training_videos/today');
    final r = await _req(
      http.get(uri, headers: await _headers(auth: true)),
    );
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw
        .map((e) => TrainingVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registra a conclusão diária de um vídeo de treinamento.
  /// Endpoint esperado: POST /me/training_videos/{id}/complete
  Future<TrainingVideoCompletionResult> completeTrainingVideo(
    String trainingVideoId,
  ) async {
    final uri =
        Uri.parse('$baseUrl/me/training_videos/$trainingVideoId/complete');
    final r = await _req(http.post(
      uri,
      headers: await _jsonHeaders(auth: true),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = (data ?? {}) as Map<String, dynamic>;
    return TrainingVideoCompletionResult.fromJson(map);
  }

  /// Lista todos os vídeos de treinamento (admin/professor).
  /// Endpoint esperado: GET /training_videos
  Future<List<TrainingVideo>> getTrainingVideosAdmin() async {
    final uri = Uri.parse('$baseUrl/training_videos');
    final r = await _req(http.get(uri, headers: await _headers(auth: true)));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw
        .map((e) => TrainingVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria vídeo de treinamento (admin/professor).
  Future<void> createTrainingVideo({
    required String title,
    required String youtubeUrl,
    required int pointsPerDay,
    bool isActive = true,
    int? durationSeconds,
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
    final r = await _req(http.post(
      Uri.parse('$baseUrl/training_videos'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  /// Atualiza vídeo de treinamento (admin/professor).
  Future<void> updateTrainingVideo({
    required String id,
    required String title,
    required String youtubeUrl,
    required int pointsPerDay,
    required bool isActive,
    int? durationSeconds,
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
    final r = await _req(http.put(
      Uri.parse('$baseUrl/training_videos/$id'),
      headers: await _jsonHeaders(auth: true),
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  /// Remove vídeo de treinamento (admin/professor).
  Future<void> deleteTrainingVideo(String id) async {
    final r = await _req(http.delete(
      Uri.parse('$baseUrl/training_videos/$id'),
      headers: await _headers(auth: true),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }
}


