import 'package:viewer/utils/form_utils.dart';

class EngagementPeriodMetrics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalStudents;
  final int activeStudents;
  final double activeRate;

  EngagementPeriodMetrics({
    required this.startDate,
    required this.endDate,
    required this.totalStudents,
    required this.activeStudents,
    required this.activeRate,
  });

  factory EngagementPeriodMetrics.fromJson(Map<String, dynamic> json) {
    final start = parseApiDate(json['start_date'] as String?);
    final end = parseApiDate(json['end_date'] as String?);
    return EngagementPeriodMetrics(
      startDate: start ?? DateTime.now(),
      endDate: end ?? DateTime.now(),
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudents: (json['active_students'] as num?)?.toInt() ?? 0,
      activeRate: (json['active_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EngagementReport {
  final String? academyId;
  final EngagementPeriodMetrics weekly;
  final EngagementPeriodMetrics monthly;

  EngagementReport({
    required this.academyId,
    required this.weekly,
    required this.monthly,
  });

  factory EngagementReport.fromJson(Map<String, dynamic> json) {
    return EngagementReport(
      academyId: json['academy_id'] as String?,
      weekly: EngagementPeriodMetrics.fromJson(
        json['weekly'] as Map<String, dynamic>,
      ),
      monthly: EngagementPeriodMetrics.fromJson(
        json['monthly'] as Map<String, dynamic>,
      ),
    );
  }
}

