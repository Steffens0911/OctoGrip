import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viewer/config.dart';
import 'package:viewer/models/professor.dart';
import 'package:viewer/services/auth_service.dart';

class ProfessorServiceException implements Exception {
  final String message;
  ProfessorServiceException(this.message);
  @override
  String toString() => message;
}

class ProfessorService {
  ProfessorService({String? baseUrl}) : _base = baseUrl ?? kApiBaseUrl;
  final String _base;

  String get _professorsUrl => '$_base/professors';

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

  Future<List<Professor>> list({String? academyId}) async {
    await AuthService().ensureLoaded();
    final uri = academyId != null
        ? Uri.parse('$_professorsUrl?academy_id=$academyId')
        : Uri.parse(_professorsUrl);
    final response = await http.get(uri, headers: _getHeaders(auth: true));
    if (response.statusCode != 200) {
      throw ProfessorServiceException(
          'Falha ao listar professores: ${response.statusCode}');
    }
    final list = json.decode(response.body) as List<dynamic>;
    return list.map((e) => Professor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Professor?> get(String id) async {
    await AuthService().ensureLoaded();
    final response = await http.get(Uri.parse('$_professorsUrl/$id'), headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ProfessorServiceException(
          'Falha ao buscar professor: ${response.statusCode}');
    }
    return Professor.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Professor> create({
    required String name,
    required String email,
    String? academyId,
  }) async {
    await AuthService().ensureLoaded();
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      if (academyId != null) 'academy_id': academyId,
    };
    final response = await http.post(
      Uri.parse(_professorsUrl),
      headers: _getJsonHeaders(auth: true),
      body: json.encode(body),
    );
    if (response.statusCode == 409) {
      throw ProfessorServiceException('E-mail já cadastrado.');
    }
    if (response.statusCode != 201) {
      throw ProfessorServiceException(
          'Falha ao criar professor: ${response.statusCode}');
    }
    return Professor.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<Professor?> update(
    String id, {
    String? name,
    String? email,
    String? academyId,
  }) async {
    await AuthService().ensureLoaded();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (academyId != null) body['academy_id'] = academyId;
    if (body.isEmpty) return get(id);
    final response = await http.patch(
      Uri.parse('$_professorsUrl/$id'),
      headers: _getJsonHeaders(auth: true),
      body: json.encode(body),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode == 409) {
      throw ProfessorServiceException('E-mail já cadastrado.');
    }
    if (response.statusCode != 200) {
      throw ProfessorServiceException(
          'Falha ao atualizar professor: ${response.statusCode}');
    }
    return Professor.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  Future<bool> delete(String id) async {
    await AuthService().ensureLoaded();
    final response = await http.delete(Uri.parse('$_professorsUrl/$id'), headers: _getHeaders(auth: true));
    if (response.statusCode == 404) return false;
    if (response.statusCode != 204) {
      throw ProfessorServiceException(
          'Falha ao excluir professor: ${response.statusCode}');
    }
    return true;
  }
}
