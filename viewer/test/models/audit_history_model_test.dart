import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/audit_history.dart';

void main() {
  group('AuditLogItem.fromJson', () {
    test('desserializa todos os campos', () {
      final item = AuditLogItem.fromJson({
        'id': 'log-1',
        'user_id': 'u1',
        'action': 'UPDATE',
        'entity': 'users',
        'entity_id': 'u2',
        'old_data': {'name': 'Antigo'},
        'new_data': {'name': 'Novo'},
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(item.id, 'log-1');
      expect(item.userId, 'u1');
      expect(item.action, 'UPDATE');
      expect(item.entity, 'users');
      expect(item.entityId, 'u2');
      expect(item.oldData, {'name': 'Antigo'});
      expect(item.newData, {'name': 'Novo'});
      expect(item.createdAt, '2024-01-01T00:00:00Z');
    });

    test('aceita campos opcionais nulos', () {
      final item = AuditLogItem.fromJson({
        'id': 'log-2',
        'user_id': null,
        'action': 'DELETE',
        'entity': 'attendances',
        'entity_id': 'a1',
        'created_at': '2024-06-01T10:00:00Z',
      });

      expect(item.userId, isNull);
      expect(item.oldData, isNull);
      expect(item.newData, isNull);
    });
  });

  group('AuditHistoryResult.fromJson', () {
    test('desserializa lista de itens e metadados', () {
      final result = AuditHistoryResult.fromJson({
        'items': [
          {
            'id': 'log-1',
            'user_id': null,
            'action': 'CREATE',
            'entity': 'missions',
            'entity_id': 'm1',
            'created_at': '2024-01-01T00:00:00Z',
          },
        ],
        'total': 1,
        'limit': 50,
        'offset': 0,
        'order': 'desc',
      });

      expect(result.items.length, 1);
      expect(result.total, 1);
      expect(result.limit, 50);
      expect(result.offset, 0);
      expect(result.order, 'desc');
    });

    test('usa order "asc" como padrão quando ausente', () {
      final result = AuditHistoryResult.fromJson({
        'items': [],
        'total': 0,
        'limit': 10,
        'offset': 0,
      });

      expect(result.order, 'asc');
      expect(result.items, isEmpty);
    });
  });

  group('RestoreResult.fromJson', () {
    test('desserializa todos os campos', () {
      final r = RestoreResult.fromJson({
        'restored': true,
        'mode': 'create',
        'entity': 'users',
        'id': 'u1',
        'from_audit_log_id': 'log-5',
      });

      expect(r.restored, isTrue);
      expect(r.mode, 'create');
      expect(r.entity, 'users');
      expect(r.id, 'u1');
      expect(r.fromAuditLogId, 'log-5');
    });

    test('aceita fromAuditLogId nulo', () {
      final r = RestoreResult.fromJson({
        'restored': false,
        'mode': 'delete',
        'entity': 'missions',
        'id': 'm1',
      });

      expect(r.fromAuditLogId, isNull);
    });
  });
}
