class PunctualityStudentEntry {
  final String studentId;
  final String? name;
  final int punctualityStreak;
  final int punctualityStreakBest;
  final int punctualCount;
  final int lateCount;
  final int totalCheckins;
  final double punctualityPct;

  const PunctualityStudentEntry({
    required this.studentId,
    this.name,
    required this.punctualityStreak,
    required this.punctualityStreakBest,
    required this.punctualCount,
    required this.lateCount,
    required this.totalCheckins,
    required this.punctualityPct,
  });

  factory PunctualityStudentEntry.fromJson(Map<String, dynamic> json) =>
      PunctualityStudentEntry(
        studentId: json['student_id'] as String,
        name: json['name'] as String?,
        punctualityStreak: json['punctuality_streak'] as int? ?? 0,
        punctualityStreakBest: json['punctuality_streak_best'] as int? ?? 0,
        punctualCount: json['punctual_count'] as int? ?? 0,
        lateCount: json['late_count'] as int? ?? 0,
        totalCheckins: json['total_checkins'] as int? ?? 0,
        punctualityPct: (json['punctuality_pct'] as num?)?.toDouble() ?? 0.0,
      );
}

class PunctualityReport {
  final String academyId;
  final int days;
  final List<PunctualityStudentEntry> students;

  const PunctualityReport({
    required this.academyId,
    required this.days,
    required this.students,
  });

  factory PunctualityReport.fromJson(Map<String, dynamic> json) =>
      PunctualityReport(
        academyId: json['academy_id'] as String,
        days: json['days'] as int? ?? 30,
        students: (json['students'] as List<dynamic>?)
                ?.map((e) => PunctualityStudentEntry.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  double get avgPct {
    if (students.isEmpty) return 0;
    return students.map((s) => s.punctualityPct).reduce((a, b) => a + b) /
        students.length;
  }

  int get maxActiveStreak {
    if (students.isEmpty) return 0;
    return students
        .map((s) => s.punctualityStreak)
        .reduce((a, b) => a > b ? a : b);
  }
}
