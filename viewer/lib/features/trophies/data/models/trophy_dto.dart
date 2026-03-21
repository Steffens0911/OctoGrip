class TrophyDto {
  const TrophyDto({
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

  factory TrophyDto.fromJson(Map<String, dynamic> json, {required String academyId}) {
    String d(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    return TrophyDto(
      id: d(json['id']),
      academyId: json['academy_id'] != null ? d(json['academy_id']) : academyId,
      techniqueId: d(json['technique_id']),
      name: json['name'] as String,
      startDateIso: d(json['start_date']),
      endDateIso: d(json['end_date']),
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      awardKind: json['award_kind'] as String? ?? 'trophy',
      techniqueName: json['technique_name'] as String?,
      minDurationDays: (json['min_duration_days'] as num?)?.toInt(),
      minPointsToUnlock: (json['min_points_to_unlock'] as num?)?.toInt() ?? 0,
      minGraduationToUnlock: json['min_graduation_to_unlock'] as String?,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'id': id,
        'academy_id': academyId,
        'technique_id': techniqueId,
        'name': name,
        'start_date': startDateIso,
        'end_date': endDateIso,
        'target_count': targetCount,
        'award_kind': awardKind,
        'technique_name': techniqueName,
        'min_duration_days': minDurationDays,
        'min_points_to_unlock': minPointsToUnlock,
        'min_graduation_to_unlock': minGraduationToUnlock,
      };

  factory TrophyDto.fromHiveMap(Map<dynamic, dynamic> map) {
    return TrophyDto(
      id: map['id'] as String,
      academyId: map['academy_id'] as String,
      techniqueId: map['technique_id'] as String,
      name: map['name'] as String,
      startDateIso: map['start_date'] as String,
      endDateIso: map['end_date'] as String,
      targetCount: (map['target_count'] as num).toInt(),
      awardKind: map['award_kind'] as String? ?? 'trophy',
      techniqueName: map['technique_name'] as String?,
      minDurationDays: (map['min_duration_days'] as num?)?.toInt(),
      minPointsToUnlock: (map['min_points_to_unlock'] as num?)?.toInt() ?? 0,
      minGraduationToUnlock: map['min_graduation_to_unlock'] as String?,
    );
  }
}
