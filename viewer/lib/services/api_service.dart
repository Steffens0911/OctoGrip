import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:viewer/config.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/mission_history_item.dart';
import 'package:viewer/models/mission_today.dart';
import 'package:viewer/models/position.dart';
import 'package:viewer/models/technique.dart';
import 'package:viewer/models/usage_metrics.dart';
import 'package:viewer/models/user.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  late final String baseUrl;
  static const _timeout = Duration(seconds: 15);

  ApiService._() {
    baseUrl = kApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  Future<http.Response> _req(Future<http.Response> f) => f.timeout(_timeout);

  Future<dynamic> _decodeResponse(http.Response r) async {
    final body = r.body;
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }

  void _throwIfNotOk(http.Response r, [dynamic data]) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
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
    final r = await _req(http.get(Uri.parse('$baseUrl/academies')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Academy.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Academy> getAcademy(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/academies/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy> createAcademy({required String name, String? slug}) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/academies'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'slug': slug}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<Academy> updateAcademyTheme(String id, String? weeklyTheme) async {
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'weekly_theme': weeklyTheme}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  /// Atualiza academia (nome, slug e/ou tema). Campos omitidos não são alterados.
  Future<Academy> updateAcademy(
    String id, {
    String? name,
    String? slug,
    String? weeklyTheme,
    String? weeklyTechniqueId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (weeklyTheme != null) body['weekly_theme'] = weeklyTheme;
    if (weeklyTechniqueId != null) body['weekly_technique_id'] = weeklyTechniqueId;
    if (body.isEmpty) return getAcademy(id);
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/academies/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Academy.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteAcademy(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/academies/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
  }

  // ---------- Users ----------
  Future<List<UserModel>> getUsers() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/users')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserModel> getUser(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/users/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> createUser({
    required String email,
    String? name,
    String? academyId,
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'academy_id': academyId,
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(String id, {String? name, String? academyId}) async {
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'academy_id': academyId}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/users/$id')));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Lessons ----------
  Future<List<Lesson>> getLessons() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/lessons')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Lesson> getLesson(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/lessons/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<Lesson> createLesson({
    required String techniqueId,
    required String title,
    required String slug,
    String? videoUrl,
    String? content,
    int orderIndex = 0,
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/lessons'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'technique_id': techniqueId,
        'title': title,
        'slug': slug,
        'video_url': videoUrl,
        'content': content,
        'order_index': orderIndex,
      }),
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Lesson.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteLesson(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/lessons/$id')));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Techniques ----------
  Future<List<Technique>> getTechniques() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/techniques')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Technique.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Technique> getTechnique(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/techniques/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<Technique> createTechnique({
    required String name,
    required String slug,
    String? description,
    required String fromPositionId,
    required String toPositionId,
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/techniques'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'slug': slug,
        'description': description,
        'from_position_id': fromPositionId,
        'to_position_id': toPositionId,
      }),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<Technique> updateTechnique(
    String id, {
    String? name,
    String? slug,
    String? description,
    String? fromPositionId,
    String? toPositionId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (description != null) body['description'] = description;
    if (fromPositionId != null) body['from_position_id'] = fromPositionId;
    if (toPositionId != null) body['to_position_id'] = toPositionId;
    final r = await _req(http.put(
      Uri.parse('$baseUrl/techniques/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteTechnique(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/techniques/$id')));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Positions ----------
  Future<List<Position>> getPositions() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/positions')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Position.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Position> getPosition(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/positions/$id')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<Position> createPosition({
    required String name,
    required String slug,
    String? description,
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/positions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'slug': slug, 'description': description}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<Position> updatePosition(
    String id, {
    String? name,
    String? slug,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (description != null) body['description'] = description;
    final r = await _req(http.put(
      Uri.parse('$baseUrl/positions/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deletePosition(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/positions/$id')));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Missions ----------
  Future<List<Mission>> getMissions() async {
    final r = await _req(http.get(Uri.parse('$baseUrl/missions')));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Mission.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Mission> getMission(String id) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/missions/$id')));
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
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/missions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'technique_id': techniqueId,
        'start_date': startDate,
        'end_date': endDate,
        'level': level,
        'theme': theme,
        'academy_id': academyId,
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
  }) async {
    final body = <String, dynamic>{};
    if (techniqueId != null) body['technique_id'] = techniqueId;
    if (startDate != null) body['start_date'] = startDate;
    if (endDate != null) body['end_date'] = endDate;
    if (level != null) body['level'] = level;
    if (theme != null) body['theme'] = theme;
    if (academyId != null) body['academy_id'] = academyId;
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/missions/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Mission.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteMission(String id) async {
    final r = await _req(http.delete(Uri.parse('$baseUrl/missions/$id')));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Área do aluno (missão do dia, conclusão, histórico, feedback, métricas) ----------
  Future<MissionToday> getMissionToday({
    String level = 'beginner',
    String? userId,
    String? academyId,
  }) async {
    var uri = Uri.parse('$baseUrl/mission_today').replace(queryParameters: {
      'level': level,
      if (userId != null) 'user_id': userId,
      if (academyId != null) 'academy_id': academyId,
    });
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionToday.fromJson(data! as Map<String, dynamic>);
  }

  /// Lista das 3 missões da semana (Seg–Ter, Qua–Qui, Sex–Dom) para exibição ao aluno.
  Future<MissionWeek> getMissionWeek({
    String level = 'beginner',
    String? userId,
    String? academyId,
  }) async {
    var uri = Uri.parse('$baseUrl/mission_today/week').replace(queryParameters: {
      'level': level,
      if (userId != null) 'user_id': userId,
      if (academyId != null) 'academy_id': academyId,
    });
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return MissionWeek.fromJson(data! as Map<String, dynamic>);
  }

  /// Indica se a lição já foi concluída pelo usuário (para botão desabilitado ao abrir).
  Future<bool> getLessonCompleteStatus({required String userId, required String lessonId}) async {
    final uri = Uri.parse('$baseUrl/lesson_complete/status').replace(queryParameters: {
      'user_id': userId,
      'lesson_id': lessonId,
    });
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    return map['completed'] as bool? ?? false;
  }

  Future<void> postLessonComplete({required String userId, required String lessonId}) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/lesson_complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'lesson_id': lessonId}),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  /// Conclusão por missão (missão do dia). usageType: before_training | after_training.
  Future<void> postMissionComplete({
    required String userId,
    required String missionId,
    String usageType = 'after_training',
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/mission_complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'mission_id': missionId,
        'usage_type': usageType,
      }),
    ));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  Future<List<MissionHistoryItem>> getMissionUsagesHistory(String userId, {int limit = 7}) async {
    final uri = Uri.parse('$baseUrl/mission_usages/history').replace(queryParameters: {
      'user_id': userId,
      'limit': limit.toString(),
    });
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final map = data! as Map<String, dynamic>;
    final list = map['missions'] as List<dynamic>? ?? [];
    return list.map((e) => MissionHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> postTrainingFeedback({
    required String userId,
    required String positionId,
    String? observation,
  }) async {
    final body = <String, dynamic>{'user_id': userId, 'position_id': positionId};
    if (observation != null && observation.isNotEmpty) body['observation'] = observation;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/training_feedback'),
      headers: {'Content-Type': 'application/json'},
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
}
