import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viewer/config.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/services/auth_service.dart';

class AcademyServiceException implements Exception {
  final String message;
  AcademyServiceException(this.message);
  @override
  String toString() => message;
}

class AcademyService {
  AcademyService({String? baseUrl}) : _base = baseUrl ?? kApiBaseUrl;
  final String _base;

  String get _academiesUrl => '$_base/academies';

  Map<String, String> _getHeaders({bool auth = false}) {
    final headers = <String, String>{};
    if (auth) {
      final bearer = AuthService().authHeader;
      if (bearer != null) headers['Authorization'] = bearer;
      final impersonate = AuthService().impersonatedUserId;
      if (impersonate != null) headers['X-Impersonate-User'] = impersonate;
    }
    return headers;
  }

  Map<String, String> _getJsonHeaders({bool auth = false}) {
    final headers = _getHeaders(auth: auth);
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  Future<List<Academy>> list() async {
    await AuthService().ensureLoaded();
    final response = await http.get(Uri.parse(_academiesUrl), headers: _getHeaders(auth: true));
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao listar academias: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list
        .map((e) => Academy.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Academy?> get(String id) async {
    await AuthService().ensureLoaded();
    final response = await http.get(Uri.parse('$_academiesUrl/$id'), headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao buscar academia: ${response.statusCode}');
    }
    return Academy.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Academy> create({
    required String name,
    String? slug,
  }) async {
    await AuthService().ensureLoaded();
    final body = <String, dynamic>{
      'name': name,
      if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
    };
    final response = await http.post(
      Uri.parse(_academiesUrl),
      headers: _getJsonHeaders(auth: true),
      body: json.encode(body),
    );
    if (response.statusCode != 201) {
      throw AcademyServiceException(
          'Falha ao criar academia: ${response.statusCode}');
    }
    return Academy.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Academy?> update(
    String id, {
    String? name,
    String? slug,
    String? weeklyTheme,
    String? weeklyTechniqueId,
    String? weeklyTechnique2Id,
    String? weeklyTechnique3Id,
  }) async {
    await AuthService().ensureLoaded();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (slug != null) body['slug'] = slug;
    if (weeklyTheme != null) body['weekly_theme'] = weeklyTheme;
    if (weeklyTechniqueId != null) body['weekly_technique_id'] = weeklyTechniqueId;
    if (weeklyTechnique2Id != null) body['weekly_technique_2_id'] = weeklyTechnique2Id;
    if (weeklyTechnique3Id != null) body['weekly_technique_3_id'] = weeklyTechnique3Id;
    if (body.isEmpty) return get(id);
    final response = await http.patch(
      Uri.parse('$_academiesUrl/$id'),
      headers: _getJsonHeaders(auth: true),
      body: json.encode(body),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao atualizar academia: ${response.statusCode}');
    }
    return Academy.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  /// Atualiza as 3 missões e pontuações base. Pontos ao confirmar = pontuação base do slot × faixa do oponente.
  Future<Academy?> updateWeeklyMissions(
    String id, {
    String? weeklyTechniqueId,
    String? weeklyTechnique2Id,
    String? weeklyTechnique3Id,
    int? weeklyMultiplier1,
    int? weeklyMultiplier2,
    int? weeklyMultiplier3,
  }) async {
    await AuthService().ensureLoaded();
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
    final response = await http.patch(
      Uri.parse('$_academiesUrl/$id'),
      headers: _getJsonHeaders(auth: true),
      body: json.encode(body),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao atualizar missões: ${response.statusCode}');
    }
    return Academy.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<bool> delete(String id) async {
    await AuthService().ensureLoaded();
    final response = await http.delete(Uri.parse('$_academiesUrl/$id'), headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return false;
    if (response.statusCode != 204) {
      throw AcademyServiceException(
          'Falha ao excluir academia: ${response.statusCode}');
    }
    return true;
  }

  /// Ranking interno (últimos [periodDays] dias). [limit] máx 100.
  Future<Map<String, dynamic>> getRanking(
    String academyId, {
    int periodDays = 30,
    int limit = 50,
  }) async {
    await AuthService().ensureLoaded();
    final uri = Uri.parse('$_academiesUrl/$academyId/ranking')
        .replace(queryParameters: {
      'period_days': periodDays.toString(),
      'limit': limit.toString(),
    });
    final response = await http.get(uri, headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return {};
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao buscar ranking: ${response.statusCode}');
    }
    final map = json.decode(response.body) as Map<String, dynamic>;
    final entries = (map['entries'] as List<dynamic>?)
        ?.map((e) => AcademyRankingEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return {
      'academy_id': map['academy_id'],
      'period_days': map['period_days'] as int,
      'entries': entries,
    };
  }

  /// Posições mais reportadas como difíceis. [limit] máx 100.
  Future<Map<String, dynamic>> getDifficulties(
    String academyId, {
    int limit = 50,
  }) async {
    await AuthService().ensureLoaded();
    final uri = Uri.parse('$_academiesUrl/$academyId/difficulties')
        .replace(queryParameters: {'limit': limit.toString()});
    final response = await http.get(uri, headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return {};
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao buscar dificuldades: ${response.statusCode}');
    }
    final map = json.decode(response.body) as Map<String, dynamic>;
    final entries = (map['entries'] as List<dynamic>?)
        ?.map((e) =>
            AcademyDifficultyEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return {
      'academy_id': map['academy_id'],
      'entries': entries,
    };
  }

  /// Reinicia as missões da academia: limpa conclusões/execuções, preservando pontos.
  Future<Map<String, dynamic>> resetMissions(String academyId) async {
    await AuthService().ensureLoaded();
    final response = await http.post(
      Uri.parse('$_academiesUrl/$academyId/reset_missions'),
      headers: _getJsonHeaders(auth: true),
    );
    if (response.statusCode == 404) {
      throw AcademyServiceException('Academia não encontrada.');
    }
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao reiniciar missões: ${response.statusCode}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Relatório semanal. [year] e [week] opcionais (ISO); se omitidos, semana atual.
  Future<AcademyWeeklyReport?> getWeeklyReport(
    String academyId, {
    int? year,
    int? week,
  }) async {
    await AuthService().ensureLoaded();
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (week != null) queryParams['week'] = week.toString();
    final uri = Uri.parse('$_academiesUrl/$academyId/report/weekly')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(uri, headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AcademyServiceException(
          'Falha ao buscar relatório: ${response.statusCode}');
    }
    return AcademyWeeklyReport.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }
}
