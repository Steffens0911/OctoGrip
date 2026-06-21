import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';

TrophyEntity _entity({
  String id = 'tr1',
  String academyId = 'ac1',
  String techniqueId = 'tech1',
  String name = 'Troféu de Ouro',
  String startDate = '2024-01-01',
  String endDate = '2024-12-31',
  int targetCount = 10,
  String awardKind = 'gold',
}) =>
    TrophyEntity(
      id: id,
      academyId: academyId,
      techniqueId: techniqueId,
      name: name,
      startDateIso: startDate,
      endDateIso: endDate,
      targetCount: targetCount,
      awardKind: awardKind,
    );

void main() {
  group('TrophyEntity — construção', () {
    test('cria entidade com campos obrigatórios', () {
      final e = _entity();

      expect(e.id, 'tr1');
      expect(e.academyId, 'ac1');
      expect(e.name, 'Troféu de Ouro');
      expect(e.targetCount, 10);
      expect(e.minRewardLevelToUnlock, 0);
    });

    test('campos opcionais nulos por padrão', () {
      final e = _entity();

      expect(e.techniqueName, isNull);
      expect(e.minDurationDays, isNull);
      expect(e.minGraduationToUnlock, isNull);
      expect(e.maxCountPerOpponent, isNull);
    });
  });

  group('TrophyEntity — copyWith', () {
    test('copia com nome alterado', () {
      final original = _entity(name: 'Original');
      final copy = original.copyWith(name: 'Novo Nome');

      expect(copy.id, original.id);
      expect(copy.name, 'Novo Nome');
      expect(copy.academyId, original.academyId);
    });

    test('copia com targetCount alterado', () {
      final original = _entity(targetCount: 5);
      final copy = original.copyWith(targetCount: 20);

      expect(copy.targetCount, 20);
      expect(copy.awardKind, original.awardKind);
    });

    test('copia sem alterações mantém todos os campos', () {
      final original = _entity();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.targetCount, original.targetCount);
    });
  });

  group('TrophyEntity — igualdade (Equatable)', () {
    test('dois entidades com mesmos props são iguais', () {
      final a = _entity(id: 'tr1');
      final b = _entity(id: 'tr1');

      expect(a, equals(b));
    });

    test('entidades com ids diferentes não são iguais', () {
      final a = _entity(id: 'tr1');
      final b = _entity(id: 'tr2');

      expect(a, isNot(equals(b)));
    });

    test('props contém os campos esperados', () {
      final e = _entity(id: 'tr1', academyId: 'ac1');

      expect(e.props, contains('tr1'));
      expect(e.props, contains('ac1'));
    });
  });
}
