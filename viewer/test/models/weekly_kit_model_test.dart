import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/weekly_kit.dart';

void main() {
  group('WeeklyKitItemRead.fromJson', () {
    test('desserializa todos os campos', () {
      final item = WeeklyKitItemRead.fromJson({
        'order_index': 2,
        'technique_id': 'tech-1',
        'technique_name': 'Armlock',
        'multiplier': 15,
      });

      expect(item.orderIndex, 2);
      expect(item.techniqueId, 'tech-1');
      expect(item.techniqueName, 'Armlock');
      expect(item.multiplier, 15);
    });

    test('usa defaults quando order_index e multiplier ausentes', () {
      final item = WeeklyKitItemRead.fromJson({'technique_id': 'tech-2'});

      expect(item.orderIndex, 0);
      expect(item.multiplier, 10);
      expect(item.techniqueName, isNull);
    });
  });

  group('WeeklyKitItemRead.toJson', () {
    test('serializa campos obrigatórios', () {
      final item = WeeklyKitItemRead(
        orderIndex: 1,
        techniqueId: 'tech-1',
        multiplier: 10,
      );
      final json = item.toJson();

      expect(json['order_index'], 1);
      expect(json['technique_id'], 'tech-1');
      expect(json['multiplier'], 10);
      expect(json.containsKey('technique_name'), isFalse);
    });

    test('inclui technique_name quando presente', () {
      final item = WeeklyKitItemRead(
        orderIndex: 0,
        techniqueId: 'tech-3',
        techniqueName: 'Kimura',
        multiplier: 20,
      );
      final json = item.toJson();

      expect(json['technique_name'], 'Kimura');
    });
  });
}
