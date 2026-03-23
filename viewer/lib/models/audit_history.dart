/// Respostas da API `/admin/audit` e `/admin/restore`.
class AuditLogItem {
  AuditLogItem({
    required this.id,
    required this.userId,
    required this.action,
    required this.entity,
    required this.entityId,
    this.oldData,
    this.newData,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String action;
  final String entity;
  final String entityId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String createdAt;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      action: json['action'] as String,
      entity: json['entity'] as String,
      entityId: json['entity_id'] as String,
      oldData: json['old_data'] != null
          ? Map<String, dynamic>.from(json['old_data'] as Map)
          : null,
      newData: json['new_data'] != null
          ? Map<String, dynamic>.from(json['new_data'] as Map)
          : null,
      createdAt: json['created_at'] as String,
    );
  }
}

class AuditHistoryResult {
  AuditHistoryResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.order,
  });

  final List<AuditLogItem> items;
  final int total;
  final int limit;
  final int offset;
  final String order;

  factory AuditHistoryResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return AuditHistoryResult(
      items: raw
          .map((e) => AuditLogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      order: json['order'] as String? ?? 'asc',
    );
  }
}

class RestoreResult {
  RestoreResult({
    required this.restored,
    required this.mode,
    required this.entity,
    required this.id,
    this.fromAuditLogId,
  });

  final bool restored;
  final String mode;
  final String entity;
  final String id;
  final String? fromAuditLogId;

  factory RestoreResult.fromJson(Map<String, dynamic> json) {
    return RestoreResult(
      restored: json['restored'] as bool,
      mode: json['mode'] as String,
      entity: json['entity'] as String,
      id: json['id'] as String,
      fromAuditLogId: json['from_audit_log_id'] as String?,
    );
  }
}
