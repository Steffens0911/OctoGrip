import 'package:equatable/equatable.dart';

class TrophyEntity extends Equatable {
  const TrophyEntity({
    required this.id,
    required this.academyId,
    required this.techniqueId,
    required this.name,
    required this.startDateIso,
    required this.endDateIso,
    required this.targetCount,
    required this.awardKind,
    this.techniqueName,
    this.minDurationDays,
    this.minPointsToUnlock = 0,
    this.minGraduationToUnlock,
  });

  final String id;
  final String academyId;
  final String techniqueId;
  final String name;
  final String startDateIso;
  final String endDateIso;
  final int targetCount;
  final String awardKind;
  final String? techniqueName;
  final int? minDurationDays;
  final int minPointsToUnlock;
  final String? minGraduationToUnlock;

  TrophyEntity copyWith({
    String? id,
    String? academyId,
    String? techniqueId,
    String? name,
    String? startDateIso,
    String? endDateIso,
    int? targetCount,
    String? awardKind,
    String? techniqueName,
    int? minDurationDays,
    int? minPointsToUnlock,
    String? minGraduationToUnlock,
  }) {
    return TrophyEntity(
      id: id ?? this.id,
      academyId: academyId ?? this.academyId,
      techniqueId: techniqueId ?? this.techniqueId,
      name: name ?? this.name,
      startDateIso: startDateIso ?? this.startDateIso,
      endDateIso: endDateIso ?? this.endDateIso,
      targetCount: targetCount ?? this.targetCount,
      awardKind: awardKind ?? this.awardKind,
      techniqueName: techniqueName ?? this.techniqueName,
      minDurationDays: minDurationDays ?? this.minDurationDays,
      minPointsToUnlock: minPointsToUnlock ?? this.minPointsToUnlock,
      minGraduationToUnlock: minGraduationToUnlock ?? this.minGraduationToUnlock,
    );
  }

  @override
  List<Object?> get props => [id, academyId, techniqueId, name, startDateIso, endDateIso, targetCount, awardKind];
}
