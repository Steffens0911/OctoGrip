import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/notification_model.dart';

void main() {
  group('NotificationModel.fromJson', () {
    test('mapeia payload completo incluindo data e created_at', () {
      final json = {
        'id': 'n1',
        'type': 'trophy_earned',
        'title': 'Novo troféu!',
        'body': 'Você conquistou um troféu',
        'read': true,
        'data': {'trophy_id': 'tr1'},
        'created_at': '2026-06-15T10:30:00Z',
      };

      final n = NotificationModel.fromJson(json);

      expect(n.id, 'n1');
      expect(n.type, 'trophy_earned');
      expect(n.title, 'Novo troféu!');
      expect(n.body, 'Você conquistou um troféu');
      expect(n.read, isTrue);
      expect(n.data, {'trophy_id': 'tr1'});
      expect(n.createdAt, DateTime.parse('2026-06-15T10:30:00Z'));
    });

    test('read default false e data nulo', () {
      final n = NotificationModel.fromJson({
        'id': 'n2',
        'type': 'info',
        'title': 't',
        'body': 'b',
        'created_at': '2026-06-15T00:00:00Z',
      });
      expect(n.read, isFalse);
      expect(n.data, isNull);
    });
  });

  group('NotificationModel.copyWith', () {
    test('altera apenas read e preserva o resto', () {
      final n = NotificationModel(
        id: 'n1',
        type: 'info',
        title: 't',
        body: 'b',
        read: false,
        data: const {'k': 'v'},
        createdAt: DateTime.utc(2026, 6, 15),
      );

      final updated = n.copyWith(read: true);

      expect(updated.read, isTrue);
      expect(updated.id, n.id);
      expect(updated.title, n.title);
      expect(updated.data, n.data);
      expect(updated.createdAt, n.createdAt);
    });
  });
}
