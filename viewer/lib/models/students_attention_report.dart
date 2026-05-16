class StudentAttentionItem {
  final String userId;
  final String? name;
  final String email;
  final String? graduation;
  final String? academyId;
  final String? academyName;
  final DateTime? lastSeenAt;
  final int? daysAbsent;

  StudentAttentionItem({
    required this.userId,
    this.name,
    required this.email,
    this.graduation,
    this.academyId,
    this.academyName,
    this.lastSeenAt,
    this.daysAbsent,
  });

  factory StudentAttentionItem.fromJson(Map<String, dynamic> json) {
    return StudentAttentionItem(
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String,
      graduation: json['graduation'] as String?,
      academyId: json['academy_id'] as String?,
      academyName: json['academy_name'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      daysAbsent: (json['days_absent'] as num?)?.toInt(),
    );
  }
}

class StudentsAttentionReport {
  final String? academyId;
  final int totalStudents;
  final List<StudentAttentionItem> students;

  StudentsAttentionReport({
    required this.academyId,
    required this.totalStudents,
    required this.students,
  });

  factory StudentsAttentionReport.fromJson(Map<String, dynamic> json) {
    return StudentsAttentionReport(
      academyId: json['academy_id'] as String?,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      students: (json['students'] as List<dynamic>? ?? [])
          .map((e) => StudentAttentionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
