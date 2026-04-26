class AttendanceRankingEntryModel {
  final int position;
  final String studentId;
  final String name;
  final String? avatarUrl;
  final String? belt;
  final int totalCheckins;
  final int attendancePercentage;
  final int? positionChange;

  AttendanceRankingEntryModel({
    required this.position,
    required this.studentId,
    required this.name,
    required this.avatarUrl,
    required this.belt,
    required this.totalCheckins,
    required this.attendancePercentage,
    required this.positionChange,
  });

  factory AttendanceRankingEntryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRankingEntryModel(
      position: (json['position'] as num?)?.toInt() ?? 0,
      studentId: json['student_id'] as String,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      belt: json['belt'] as String?,
      totalCheckins: (json['total_checkins'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toInt() ?? 0,
      positionChange: (json['position_change'] as num?)?.toInt(),
    );
  }
}

class AttendanceMyPositionModel {
  final int position;
  final int totalCheckins;
  final int attendancePercentage;
  final int? positionChange;

  AttendanceMyPositionModel({
    required this.position,
    required this.totalCheckins,
    required this.attendancePercentage,
    required this.positionChange,
  });

  factory AttendanceMyPositionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceMyPositionModel(
      position: (json['position'] as num?)?.toInt() ?? 0,
      totalCheckins: (json['total_checkins'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toInt() ?? 0,
      positionChange: (json['position_change'] as num?)?.toInt(),
    );
  }
}

class AttendanceRankingModel {
  final String? month;
  final String periodKind;
  final String periodLabel;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<AttendanceRankingEntryModel> ranking;
  final AttendanceMyPositionModel? myPosition;

  AttendanceRankingModel({
    required this.month,
    required this.periodKind,
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
    required this.ranking,
    required this.myPosition,
  });

  factory AttendanceRankingModel.fromJson(Map<String, dynamic> json) {
    final rankingRaw = json['ranking'] as List<dynamic>? ?? const [];
    return AttendanceRankingModel(
      month: json['month'] as String?,
      periodKind: json['period_kind'] as String? ?? 'month',
      periodLabel: json['period_label'] as String? ?? '',
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      ranking: rankingRaw
          .map((e) => AttendanceRankingEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      myPosition: json['my_position'] != null
          ? AttendanceMyPositionModel.fromJson(json['my_position'] as Map<String, dynamic>)
          : null,
    );
  }
}
