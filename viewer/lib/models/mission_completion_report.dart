import 'package:viewer/utils/form_utils.dart';

class MissionCompletionReport {
  final String? academyId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalStudents;
  final int usersCompleted;
  final double completionRate;

  MissionCompletionReport({
    required this.academyId,
    required this.fromDate,
    required this.toDate,
    required this.totalStudents,
    required this.usersCompleted,
    required this.completionRate,
  });

  factory MissionCompletionReport.fromJson(Map<String, dynamic> json) {
    return MissionCompletionReport(
      academyId: json['academy_id'] as String?,
      fromDate: parseApiDate(json['from_date'] as String?) ?? DateTime.now(),
      toDate: parseApiDate(json['to_date'] as String?) ?? DateTime.now(),
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      usersCompleted: (json['users_completed'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
