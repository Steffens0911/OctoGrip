import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';

class TrophyMapper {
  static TrophyEntity toEntity(TrophyDto dto) {
    return TrophyEntity(
      id: dto.id,
      academyId: dto.academyId,
      techniqueId: dto.techniqueId,
      name: dto.name,
      startDateIso: dto.startDateIso,
      endDateIso: dto.endDateIso,
      targetCount: dto.targetCount,
      awardKind: dto.awardKind,
      techniqueName: dto.techniqueName,
      minDurationDays: dto.minDurationDays,
      minPointsToUnlock: dto.minPointsToUnlock,
      minGraduationToUnlock: dto.minGraduationToUnlock,
    );
  }
}
