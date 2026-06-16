import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/data/mappers/trophy_mapper.dart';
import 'package:viewer/features/trophies/data/models/trophy_dto.dart';

void main() {
  const dto = TrophyDto(
    id: 'tr1',
    academyId: 'ac1',
    techniqueId: 'tech1',
    name: 'Armlock 5x',
    startDateIso: '2026-01-01',
    endDateIso: '2026-12-31',
    targetCount: 5,
    awardKind: 'trophy',
    techniqueName: 'Armlock',
    minDurationDays: 3,
    minRewardLevelToUnlock: 2,
    minGraduationToUnlock: 'azul',
    maxCountPerOpponent: 1,
  );

  group('TrophyMapper.toEntity', () {
    test('mapeia todos os campos do DTO', () {
      final e = TrophyMapper.toEntity(dto);
      expect(e.id, dto.id);
      expect(e.academyId, dto.academyId);
      expect(e.techniqueId, dto.techniqueId);
      expect(e.name, dto.name);
      expect(e.startDateIso, dto.startDateIso);
      expect(e.endDateIso, dto.endDateIso);
      expect(e.targetCount, dto.targetCount);
      expect(e.awardKind, dto.awardKind);
      expect(e.techniqueName, dto.techniqueName);
      expect(e.minDurationDays, dto.minDurationDays);
      expect(e.minRewardLevelToUnlock, dto.minRewardLevelToUnlock);
      expect(e.minGraduationToUnlock, dto.minGraduationToUnlock);
      expect(e.maxCountPerOpponent, dto.maxCountPerOpponent);
    });

    test('campos opcionais nulos são preservados', () {
      const minimal = TrophyDto(
        id: 'tr2',
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Triângulo',
        startDateIso: '2026-01-01',
        endDateIso: '2026-06-30',
        targetCount: 3,
        awardKind: 'trophy',
      );
      final e = TrophyMapper.toEntity(minimal);
      expect(e.techniqueName, isNull);
      expect(e.minDurationDays, isNull);
      expect(e.minGraduationToUnlock, isNull);
      expect(e.maxCountPerOpponent, isNull);
      expect(e.minRewardLevelToUnlock, 0);
    });
  });
}
