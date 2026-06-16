import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/data/models/trophy_dto.dart';

Map<String, dynamic> fullJson() => {
      'id': 'tr1',
      'academy_id': 'ac1',
      'technique_id': 'tech1',
      'name': 'Armlock 5x',
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'target_count': 5,
      'award_kind': 'trophy',
      'technique_name': 'Armlock',
      'min_duration_days': 3,
      'min_reward_level_to_unlock': 2,
      'min_graduation_to_unlock': 'azul',
      'max_count_per_opponent': 1,
    };

void main() {
  group('TrophyDto.fromJson', () {
    test('parseia todos os campos', () {
      final dto = TrophyDto.fromJson(fullJson(), academyId: 'ac1');
      expect(dto.id, 'tr1');
      expect(dto.academyId, 'ac1');
      expect(dto.techniqueId, 'tech1');
      expect(dto.name, 'Armlock 5x');
      expect(dto.startDateIso, '2026-01-01');
      expect(dto.endDateIso, '2026-12-31');
      expect(dto.targetCount, 5);
      expect(dto.awardKind, 'trophy');
      expect(dto.techniqueName, 'Armlock');
      expect(dto.minDurationDays, 3);
      expect(dto.minRewardLevelToUnlock, 2);
      expect(dto.minGraduationToUnlock, 'azul');
      expect(dto.maxCountPerOpponent, 1);
    });

    test('usa academy_id do JSON quando presente', () {
      final dto = TrophyDto.fromJson(fullJson(), academyId: 'outro');
      expect(dto.academyId, 'ac1'); // vem do JSON, não do parâmetro
    });

    test('usa academyId do parâmetro quando academy_id ausente no JSON', () {
      final json = Map<String, dynamic>.from(fullJson())..remove('academy_id');
      final dto = TrophyDto.fromJson(json, academyId: 'fallback');
      expect(dto.academyId, 'fallback');
    });

    test('campos opcionais ficam null/default quando ausentes', () {
      final dto = TrophyDto.fromJson({
        'id': 'tr2',
        'technique_id': 'tech1',
        'name': 'Triângulo',
        'start_date': '2026-01-01',
        'end_date': '2026-06-30',
      }, academyId: 'ac1');
      expect(dto.targetCount, 0);
      expect(dto.awardKind, 'trophy');
      expect(dto.techniqueName, isNull);
      expect(dto.minDurationDays, isNull);
      expect(dto.minRewardLevelToUnlock, 0);
      expect(dto.minGraduationToUnlock, isNull);
      expect(dto.maxCountPerOpponent, isNull);
    });

    test('target_count como num é convertido para int', () {
      final json = Map<String, dynamic>.from(fullJson())
        ..['target_count'] = 5.0;
      final dto = TrophyDto.fromJson(json, academyId: 'ac1');
      expect(dto.targetCount, isA<int>());
      expect(dto.targetCount, 5);
    });

    test('helper d() converte int para string em campos de data/id', () {
      final json = Map<String, dynamic>.from(fullJson())
        ..['id'] = 42
        ..['start_date'] = 20260101;
      final dto = TrophyDto.fromJson(json, academyId: 'ac1');
      expect(dto.id, '42');
      expect(dto.startDateIso, '20260101');
    });
  });

  group('TrophyDto fromHiveMap / toHiveMap', () {
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

    test('round-trip preserva todos os campos', () {
      final restored = TrophyDto.fromHiveMap(dto.toHiveMap());
      expect(restored.id, dto.id);
      expect(restored.academyId, dto.academyId);
      expect(restored.techniqueId, dto.techniqueId);
      expect(restored.name, dto.name);
      expect(restored.startDateIso, dto.startDateIso);
      expect(restored.endDateIso, dto.endDateIso);
      expect(restored.targetCount, dto.targetCount);
      expect(restored.awardKind, dto.awardKind);
      expect(restored.techniqueName, dto.techniqueName);
      expect(restored.minDurationDays, dto.minDurationDays);
      expect(restored.minRewardLevelToUnlock, dto.minRewardLevelToUnlock);
      expect(restored.minGraduationToUnlock, dto.minGraduationToUnlock);
      expect(restored.maxCountPerOpponent, dto.maxCountPerOpponent);
    });

    test('campos nulos preservados no round-trip', () {
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
      final restored = TrophyDto.fromHiveMap(minimal.toHiveMap());
      expect(restored.techniqueName, isNull);
      expect(restored.minDurationDays, isNull);
      expect(restored.maxCountPerOpponent, isNull);
    });

    test('fromHiveMap usa min_points_to_unlock como fallback legado', () {
      final map = dto.toHiveMap()
        ..remove('min_reward_level_to_unlock')
        ..['min_points_to_unlock'] = 7;
      final restored = TrophyDto.fromHiveMap(map);
      expect(restored.minRewardLevelToUnlock, 7);
    });

    test('fromHiveMap prefere min_reward_level_to_unlock ao campo legado', () {
      final map = dto.toHiveMap()
        ..['min_reward_level_to_unlock'] = 3
        ..['min_points_to_unlock'] = 99;
      final restored = TrophyDto.fromHiveMap(map);
      expect(restored.minRewardLevelToUnlock, 3);
    });
  });
}
