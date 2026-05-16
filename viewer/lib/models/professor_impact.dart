class TechniqueImpact {
  final String techniqueName;
  final int studentsCompleted;
  final int totalStudents;
  final double completionPct;
  final int missionsCount;

  const TechniqueImpact({
    required this.techniqueName,
    required this.studentsCompleted,
    required this.totalStudents,
    required this.completionPct,
    required this.missionsCount,
  });

  factory TechniqueImpact.fromJson(Map<String, dynamic> j) => TechniqueImpact(
        techniqueName: j['technique_name'] as String,
        studentsCompleted: j['students_completed'] as int,
        totalStudents: j['total_students'] as int,
        completionPct: (j['completion_pct'] as num).toDouble(),
        missionsCount: j['missions_count'] as int,
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
        id: j['id'] as String,
        name: j['name'] as String,
        daysInactive: j['days_inactive'] as int,
        riskLevel: j['risk_level'] as String,
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
  });

  factory ProfessorImpact.fromJson(Map<String, dynamic> j) => ProfessorImpact(
        weekStart: DateTime.parse(j['week_start'] as String),
        weekEnd: DateTime.parse(j['week_end'] as String),
        studentsReached: j['students_reached'] as int,
        totalStudents: j['total_students'] as int,
        completionRate: (j['completion_rate'] as num).toDouble(),
        completionRateDelta: j['completion_rate_delta'] == null
            ? null
            : (j['completion_rate_delta'] as num).toDouble(),
        techniques: (j['techniques'] as List)
            .map((e) => TechniqueImpact.fromJson(e as Map<String, dynamic>))
            .toList(),
        atRiskStudents: (j['at_risk_students'] as List)
            .map((e) => AtRiskStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalMissionsInAcademy: j['total_missions_in_academy'] as int,
        totalCompletionsAllTime: j['total_completions_all_time'] as int,
      );

  String get weekLabel {
    const months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    final startLabel = '${weekStart.day} ${months[weekStart.month - 1]}';
    final endLabel = '${weekEnd.day} ${months[weekEnd.month - 1]} ${weekEnd.year}';
    return '$startLabel–$endLabel';
  }
}
