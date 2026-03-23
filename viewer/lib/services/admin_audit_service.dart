import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viewer/config.dart';
import 'package:viewer/models/audit_history.dart';
import 'package:viewer/services/auth_service.dart';

class AdminAuditServiceException implements Exception {
  AdminAuditServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Chamadas a `/admin/audit` e `/admin/restore` (exige token de **administrador**).
class AdminAuditService {
  AdminAuditService({String? baseUrl}) : _base = baseUrl ?? kApiBaseUrl;
  final String _base;

  /// Evita `//` na URL quando [kApiBaseUrl] termina com `/`.
  String get _baseNormalized {
    var b = _base.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{};
    final bearer = AuthService().authHeader;
    if (bearer != null) headers['Authorization'] = bearer;
    final impersonate = AuthService().impersonatedUserId;
    if (impersonate != null) headers['X-Impersonate-User'] = impersonate;
    if (jsonBody) headers['Content-Type'] = 'application/json';
    return headers;
  }

  /// Feed global: `/admin/audit/feed`. [academyId] opcional filtra pela academia.
  /// [entity]: mission, lesson, technique, trophy (minúsculo), ou null para todas.
  Future<AuditHistoryResult> fetchFeed({
    String? academyId,
    String? entity,
    int limit = 50,
    int offset = 0,
    String? action,
    String order = 'desc',
  }) async {
    await AuthService().ensureLoaded();
    final q = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'order': order == 'desc' ? 'desc' : 'asc',
    };
    if (academyId != null && academyId.trim().isNotEmpty) {
      q['academy_id'] = academyId.trim();
    }
    if (entity != null && entity.trim().isNotEmpty) {
      q['entity'] = entity.trim().toLowerCase();
    }
    if (action != null && action.trim().isNotEmpty) {
      q['action'] = action.trim().toUpperCase();
    }
    final uri =
        Uri.parse('$_baseNormalized/admin/audit/feed').replace(queryParameters: q);
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final m = json.decode(response.body) as Map<String, dynamic>?;
        detail = m?['detail']?.toString() ?? detail;
      } catch (_) {}
      throw AdminAuditServiceException(
        'Feed de auditoria: ${response.statusCode} $detail',
        statusCode: response.statusCode,
      );
    }
    return AuditHistoryResult.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  /// [entity]: mission, lesson, technique, trophy (minúsculo).
  Future<AuditHistoryResult> fetchHistory({
    required String entity,
    required String entityId,
    int limit = 50,
    int offset = 0,
    String? action,
    String order = 'asc',
  }) async {
    await AuthService().ensureLoaded();
    final q = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'order': order == 'desc' ? 'desc' : 'asc',
    };
    if (action != null && action.trim().isNotEmpty) {
      q['action'] = action.trim().toUpperCase();
    }
    final uri = Uri.parse('$_baseNormalized/admin/audit/$entity/$entityId')
        .replace(queryParameters: q);
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final m = json.decode(response.body) as Map<String, dynamic>?;
        detail = m?['detail']?.toString() ?? detail;
      } catch (_) {}
      throw AdminAuditServiceException(
        'Histórico: ${response.statusCode} $detail',
        statusCode: response.statusCode,
      );
    }
    return AuditHistoryResult.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  /// Sem [auditLogId]: reativa registro soft-deletado. Com [auditLogId]: restaura snapshot (old_data).
  Future<RestoreResult> restore({
    required String entity,
    required String entityId,
    String? auditLogId,
  }) async {
    await AuthService().ensureLoaded();
    final q = <String, String>{};
    if (auditLogId != null && auditLogId.trim().isNotEmpty) {
      q['audit_log_id'] = auditLogId.trim();
    }
    final uri = Uri.parse('$_baseNormalized/admin/restore/$entity/$entityId')
        .replace(queryParameters: q.isEmpty ? null : q);
    final response = await http.post(uri, headers: _headers());
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final m = json.decode(response.body) as Map<String, dynamic>?;
        detail = m?['detail']?.toString() ?? detail;
      } catch (_) {}
      throw AdminAuditServiceException(
        'Restaurar: ${response.statusCode} $detail',
        statusCode: response.statusCode,
      );
    }
    return RestoreResult.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}
