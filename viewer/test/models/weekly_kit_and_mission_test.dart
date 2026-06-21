import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/constants/reward_points.dart';
import 'package:viewer/models/mission.dart';
import 'package:viewer/models/weekly_kit.dart';

// Testes para WeeklyKitItemRead, WeeklyKitRead e Mission.

void main() {
  group('WeeklyKitItemRead.fromJson', () {
    test('desserializa todos os campos', () {
      final item = WeeklyKitItemRead.fromJson({
        'order_index': 1,
        'technique_id': 'tc1',
        'technique_name': 'Triângulo',
        'multiplier': 20,
      });

      expect(item.orderIndex, 1);
      expect(item.techniqueId, 'tc1');
      expect(item.techniqueName, 'Triângulo');
      expect(item.multiplier, 20);
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final item = WeeklyKitItemRead.fromJson({
        'technique_id': 'tc2',
      });

      expect(item.orderIndex, 0);
      expect(item.multiplier, 10);
      expect(item.techniqueName, isNull);
    });

    test('toJson inclui techniqueName quando definido', () {
      final item = WeeklyKitItemRead(
        orderIndex: 2,
        techniqueId: 'tc3',
        techniqueName: 'Armlock',
        multiplier: 15,
      );

      final json = item.toJson();
      expect(json['order_index'], 2);
      expect(json['technique_name'], 'Armlock');
      expect(json['multiplier'], 15);
    });

    test('toJson omite techniqueName quando null', () {
      final item = WeeklyKitItemRead(
        orderIndex: 0,
        techniqueId: 'tc4',
        multiplier: 10,
      );

      final json = item.toJson();
      expect(json.containsKey('technique_name'), isFalse);
    });
  });

  group('WeeklyKitRead.fromJson', () {
    test('desserializa com lista de itens', () {
      final kit = WeeklyKitRead.fromJson({
        'id': 'wk1',
        'academy_id': 'ac1',
        'label': 'Turma A',
        'sort_order': 1,
        'items': [
          {'technique_id': 'tc1', 'multiplier': 10},
          {'technique_id': 'tc2', 'multiplier': 20},
        ],
      });

      expect(kit.id, 'wk1');
      expect(kit.academyId, 'ac1');
      expect(kit.label, 'Turma A');
      expect(kit.sortOrder, 1);
      expect(kit.items, hasLength(2));
    });

    test('usa defaults quando campos ausentes', () {
      final kit = WeeklyKitRead.fromJson({
        'id': 'wk2',
        'academy_id': 'ac1',
      });

      expect(kit.label, '');
      expect(kit.sortOrder, 0);
      expect(kit.items, isEmpty);
    });
  });

  group('Mission.fromJson', () {
    test('desserializa todos os campos', () {
      final m = Mission.fromJson({
        'id': 'miss1',
        'technique_id': 'tc1',
        'technique_name': 'Triângulo',
        'start_date': '2026-06-01',
        'end_date': '2026-06-07',
        'level': 'beginner',
        'theme': 'finalização',
        'academy_id': 'ac1',
        'is_active': true,
        'multiplier': 20,
      });

      expect(m.id, 'miss1');
      expect(m.techniqueId, 'tc1');
      expect(m.techniqueName, 'Triângulo');
      expect(m.startDate, '2026-06-01');
      expect(m.level, 'beginner');
      expect(m.theme, 'finalização');
      expect(m.isActive, isTrue);
      expect(m.multiplier, 20);
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final m = Mission.fromJson({
        'id': 'miss2',
        'technique_id': 'tc2',
        'start_date': '2026-06-01',
        'end_date': '2026-06-07',
        'level': 'intermediate',
      });

      expect(m.isActive, isTrue);
      expect(m.multiplier, minRewardPoints);
      expect(m.theme, isNull);
      expect(m.academyId, isNull);
    });

    test('toJson serializa todos os campos', () {
      final m = Mission(
        id: 'miss3',
        techniqueId: 'tc3',
        techniqueName: 'Armlock',
        startDate: '2026-06-08',
        endDate: '2026-06-14',
        level: 'advanced',
        theme: 'controle',
        academyId: 'ac1',
        isActive: false,
        multiplier: 30,
      );

      final json = m.toJson();
      expect(json['id'], 'miss3');
      expect(json['technique_id'], 'tc3');
      expect(json['start_date'], '2026-06-08');
      expect(json['level'], 'advanced');
      expect(json['theme'], 'controle');
      expect(json['academy_id'], 'ac1');
      expect(json['is_active'], isFalse);
      expect(json['multiplier'], 30);
    });
  });
}
