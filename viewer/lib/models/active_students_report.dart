class ActiveStudent {
  final String id;
  final String email;
  final String? name;
  final String? graduation;
  final String? academyId;
  final String? academyName;
  final DateTime? lastLoginAt;

  ActiveStudent({
    required this.id,
    required this.email,
    this.name,
    this.graduation,
    this.academyId,
    this.academyName,
    this.lastLoginAt,
  });

  factory ActiveStudent.fromJson(Map<String, dynamic> json) {
    final lastLoginStr = json['last_login_at'] as String?;
    return ActiveStudent(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      graduation: json['graduation'] as String?,
      academyId: json['academy_id'] as String?,
      academyName: json['academy_name'] as String?,
      lastLoginAt:
          lastLoginStr != null && lastLoginStr.isNotEmpty ? DateTime.parse(lastLoginStr) : null,
    );
  }
}

class ActiveStudentsReport {
  final String? academyId;
  final DateTime startDate;
  final DateTime endDate;
  final int totalStudents;
  final int activeStudents;
  final double activeRate;
  final List<ActiveStudent> students;

  ActiveStudentsReport({
    required this.academyId,
    required this.startDate,
    required this.endDate,
    required this.totalStudents,
    required this.activeStudents,
    required this.activeRate,
    required this.students,
  });

  factory ActiveStudentsReport.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) {
      final s = json[key] as String?;
      if (s == null || s.isEmpty) return DateTime.now();
      final parts = s.split('-');
      if (parts.length != 3) return DateTime.now();
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      final d = int.tryParse(parts[2]) ?? DateTime.now().day;
      return DateTime(y, m, d);
    }

    final list = (json['students'] as List<dynamic>? ?? [])
        .map((e) => ActiveStudent.fromJson(e as Map<String, dynamic>))
        .toList();

    return ActiveStudentsReport(
      academyId: json['academy_id'] as String?,
      startDate: parseDate('start_date'),
      endDate: parseDate('end_date'),
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudents: (json['active_students'] as num?)?.toInt() ?? 0,
      activeRate: (json['active_rate'] as num?)?.toDouble() ?? 0.0,
      students: list,
    );
  }
}

