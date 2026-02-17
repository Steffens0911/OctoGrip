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

  Future<Map<String, dynamic>?> getCollectiveGoalCurrent(String academyId) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/academies/$academyId/collective_goals/current')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    if (data == null) return null;
    return data as Map<String, dynamic>;
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

  /// Atualiza academia (nome, slug, tema, técnicas, lição visível). Campos omitidos não são alterados.
  /// Se [updateVisibleLesson] for true, envia [visibleLessonId] (null limpa a lição visível).
  Future<Academy> updateAcademy(
    String id, {
    String? name,
    String? slug,
    String? weeklyTheme,
    String? weeklyTechniqueId,
    String? visibleLessonId,
    bool updateVisibleLesson = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (weeklyTheme != null) body['weekly_theme'] = weeklyTheme;
    if (weeklyTechniqueId != null) body['weekly_technique_id'] = weeklyTechniqueId;
    if (updateVisibleLesson) body['visible_lesson_id'] = visibleLessonId;
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
  Future<List<UserModel>> getUsers({String? academyId}) async {
    var uri = Uri.parse('$baseUrl/users');
    if (academyId != null && academyId.isNotEmpty) {
      uri = uri.replace(queryParameters: {'academy_id': academyId});
    }
    final r = await _req(http.get(uri));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getUserPoints(String userId) async {
    final r = await _req(http.get(Uri.parse('$baseUrl/users/$userId/points')));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPointsLog(String userId, {int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/users/$userId/points_log').replace(queryParameters: {'limit': limit.toString()});
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
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
    String? graduation,
    String? academyId,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'name': name,
      'academy_id': academyId,
    };
    if (graduation != null) body['graduation'] = graduation;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return UserModel.fromJson(data! as Map<String, dynamic>);
  }

  Future<UserModel> updateUser(String id, {String? name, String? graduation, String? academyId, int? pointsAdjustment}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (graduation != null) body['graduation'] = graduation;
    if (academyId != null) body['academy_id'] = academyId;
    if (pointsAdjustment != null) body['points_adjustment'] = pointsAdjustment;
    final r = await _req(http.patch(
      Uri.parse('$baseUrl/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
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
  /// Lista lições. Se [academyId] for informado e a academia tiver lição visível, retorna só ela.
  Future<List<Lesson>> getLessons({String? academyId}) async {
    final uri = academyId != null
        ? Uri.parse('$baseUrl/lessons').replace(queryParameters: {'academy_id': academyId})
        : Uri.parse('$baseUrl/lessons');
    final r = await _req(http.get(uri));
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
      headers: {'Content-Type': 'application/json'},
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
  /// Lista técnicas da academia. [academyId] obrigatório.
  Future<List<Technique>> getTechniques({required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Technique.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Technique> getTechnique(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri));
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
    required String fromPositionId,
    required String toPositionId,
  }) async {
    final body = <String, dynamic>{
      'academy_id': academyId,
      'name': name,
      'from_position_id': fromPositionId,
      'to_position_id': toPositionId,
    };
    if (slug != null && slug.trim().isNotEmpty) body['slug'] = slug.trim();
    if (description != null) body['description'] = description;
    if (videoUrl != null && videoUrl.trim().isNotEmpty) body['video_url'] = videoUrl.trim();
    final r = await _req(http.post(
      Uri.parse('$baseUrl/techniques'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<Technique> updateTechnique(
    String id, {
    required String academyId,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
    String? fromPositionId,
    String? toPositionId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (description != null) body['description'] = description;
    if (videoUrl != null) body['video_url'] = videoUrl.trim().isEmpty ? null : videoUrl.trim();
    if (fromPositionId != null) body['from_position_id'] = fromPositionId;
    if (toPositionId != null) body['to_position_id'] = toPositionId;
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Technique.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deleteTechnique(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/techniques/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.delete(uri));
    _throwIfNotOk(r, await _decodeResponse(r));
  }

  // ---------- Positions ----------
  /// Lista posições da academia. [academyId] obrigatório.
  Future<List<Position>> getPositions({required String academyId}) async {
    final uri = Uri.parse('$baseUrl/positions').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri));
    final decoded = jsonDecode(r.body);
    _throwIfNotOk(r, decoded is Map ? decoded : null);
    final raw = decoded is List ? decoded : <dynamic>[];
    return raw.map((e) => Position.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Position> getPosition(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/positions/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<Position> createPosition({
    required String academyId,
    required String name,
    String? slug,
    String? description,
  }) async {
    final body = <String, dynamic>{'academy_id': academyId, 'name': name};
    if (slug != null && slug.trim().isNotEmpty) body['slug'] = slug.trim();
    if (description != null) body['description'] = description;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/positions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<Position> updatePosition(
    String id, {
    required String academyId,
    String? name,
    String? slug,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (description != null) body['description'] = description;
    final uri = Uri.parse('$baseUrl/positions/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return Position.fromJson(data! as Map<String, dynamic>);
  }

  Future<void> deletePosition(String id, {required String academyId}) async {
    final uri = Uri.parse('$baseUrl/positions/$id').replace(queryParameters: {'academy_id': academyId});
    final r = await _req(http.delete(uri));
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
    int multiplier = 1,
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
  /// [level] mapeado da faixa do usuário: beginner (white/blue) ou intermediate (purple/brown/black).
  Future<MissionWeek> getMissionWeek({
    String level = 'beginner',
    String? userId,
    String? academyId,
  }) async {
    final params = <String, String>{
      'level': level,
      if (userId != null) 'user_id': userId,
      if (academyId != null) 'academy_id': academyId,
    };
    var uri = Uri.parse('$baseUrl/mission_today/week').replace(queryParameters: params);
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

  // ---------- Executions (gamificação) ----------
  /// Cria execução (informe missionId ou lessonId, não ambos).
  Future<Map<String, dynamic>> postExecution({
    required String userId,
    String? missionId,
    String? lessonId,
    required String opponentId,
    String usageType = 'after_training',
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'opponent_id': opponentId,
      'usage_type': usageType,
    };
    if (missionId != null) body['mission_id'] = missionId;
    if (lessonId != null) body['lesson_id'] = lessonId;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/executions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPendingConfirmations(String userId) async {
    final uri = Uri.parse('$baseUrl/executions/pending_confirmations').replace(queryParameters: {'user_id': userId});
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> postExecutionConfirm({
    required String executionId,
    required String outcome,
    required String userId,
  }) async {
    final r = await _req(http.post(
      Uri.parse('$baseUrl/executions/$executionId/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'outcome': outcome, 'user_id': userId}),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postExecutionReject({
    required String executionId,
    required String userId,
    String? reason,
  }) async {
    final body = <String, dynamic>{'user_id': userId};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    final r = await _req(http.post(
      Uri.parse('$baseUrl/executions/$executionId/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    return data! as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyExecutions(String userId) async {
    final uri = Uri.parse('$baseUrl/executions/my_executions').replace(queryParameters: {'user_id': userId});
    final r = await _req(http.get(uri));
    final data = await _decodeResponse(r);
    _throwIfNotOk(r, data);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => e as Map<String, dynamic>).toList();
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
