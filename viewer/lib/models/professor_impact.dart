class ExecutionDetail {
  final String executorName;
  final String? opponentName;

  const ExecutionDetail({required this.executorName, this.opponentName});

  factory ExecutionDetail.fromJson(Map<String, dynamic> j) => ExecutionDetail(
        executorName: (j['executor_name'] as String? ?? ''),
        opponentName: j['opponent_name'] as String?,
      );
}

class DailyVideoView {
  final DateTime date;
  final int viewsCount;

  const DailyVideoView({required this.date, required this.viewsCount});

  factory DailyVideoView.fromJson(Map<String, dynamic> j) => DailyVideoView(
        date: (DateTime.tryParse(j['view_date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0)),
        viewsCount: ((j['views_count'] as num?)?.toInt() ?? 0),
      );
}

class TechniqueImpact {
  final String techniqueName;
  final int studentsCompleted;
  final int totalStudents;
  final double completionPct;
  final int missionsCount;
  final List<ExecutionDetail> executions;

  const TechniqueImpact({
    required this.techniqueName,
    required this.studentsCompleted,
    required this.totalStudents,
    required this.completionPct,
    required this.missionsCount,
    required this.executions,
  });

  factory TechniqueImpact.fromJson(Map<String, dynamic> j) => TechniqueImpact(
        techniqueName: (j['technique_name'] as String? ?? ''),
        studentsCompleted: ((j['students_completed'] as num?)?.toInt() ?? 0),
        totalStudents: ((j['total_students'] as num?)?.toInt() ?? 0),
        completionPct: ((j['completion_pct'] as num? ?? 0)).toDouble(),
        missionsCount: ((j['missions_count'] as num?)?.toInt() ?? 0),
        executions: (j['executions'] as List? ?? [])
            .map((e) => ExecutionDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AtRiskStudent {
  final String id;
  final String name;
  final int daysInactive;
  final String riskLevel; // "alert" | "warning"

  const AtRiskStudent({
    required this.id,
    required this.name,
    required this.daysInactive,
    required this.riskLevel,
  });

  factory AtRiskStudent.fromJson(Map<String, dynamic> j) => AtRiskStudent(
        id: (j['id'] as String? ?? ''),
        name: (j['name'] as String? ?? ''),
        daysInactive: ((j['days_inactive'] as num?)?.toInt() ?? 0),
        riskLevel: (j['risk_level'] as String? ?? ''),
      );
}

class ProfessorImpact {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int studentsReached;
  final int totalStudents;
  final double completionRate;
  final double? completionRateDelta;
  final List<TechniqueImpact> techniques;
  final List<AtRiskStudent> atRiskStudents;
  final int totalMissionsInAcademy;
  final int totalCompletionsAllTime;
  final List<DailyVideoView> dailyVideoViews;

  const ProfessorImpact({
    required this.weekStart,
    required this.weekEnd,
    required this.studentsReached,
    required this.totalStudents,
    required this.completionRate,
    required this.completionRateDelta,
    required this.techniques,
    required this.atRiskStudents,
    required this.totalMissionsInAcademy,
    required this.totalCompletionsAllTime,
    required this.dailyVideoViews,
  });

  factory ProfessorImpact.fromJson(Map<String, dynamic> j) => ProfessorImpact(
        weekStart: (DateTime.tryParse(j['week_start'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0)),
        weekEnd: (DateTime.tryParse(j['week_end'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0)),
        studentsReached: ((j['students_reached'] as num?)?.toInt() ?? 0),
        totalStudents: ((j['total_students'] as num?)?.toInt() ?? 0),
        completionRate: ((j['completion_rate'] as num? ?? 0)).toDouble(),
        completionRateDelta: j['completion_rate_delta'] == null
            ? null
            : ((j['completion_rate_delta'] as num? ?? 0)).toDouble(),
        techniques: ((j['techniques'] as List? ?? const []))
            .map((e) => TechniqueImpact.fromJson(e as Map<String, dynamic>))
            .toList(),
        atRiskStudents: ((j['at_risk_students'] as List? ?? const []))
            .map((e) => AtRiskStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalMissionsInAcademy:
            ((j['total_missions_in_academy'] as num?)?.toInt() ?? 0),
        totalCompletionsAllTime:
            ((j['total_completions_all_time'] as num?)?.toInt() ?? 0),
        dailyVideoViews: (j['daily_video_views'] as List? ?? [])
            .map((e) => DailyVideoView.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get weekLabel {
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez'
    ];
    final startLabel = '${weekStart.day} ${months[weekStart.month - 1]}';
    final endLabel =
        '${weekEnd.day} ${months[weekEnd.month - 1]} ${weekEnd.year}';
    return '$startLabel–$endLabel';
  }
}
