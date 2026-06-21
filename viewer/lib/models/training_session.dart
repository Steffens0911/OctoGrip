class TrainingTemplate {
  final String id;
  final String academyId;
  final String? label;
  final String startTime;
  final int toleranceMinutes;
  final int sortOrder;

  TrainingTemplate({
    required this.id,
    required this.academyId,
    this.label,
    required this.startTime,
    required this.toleranceMinutes,
    required this.sortOrder,
  });

  factory TrainingTemplate.fromJson(Map<String, dynamic> json) => TrainingTemplate(
        id: json['id'] as String,
        academyId: json['academy_id'] as String,
        label: json['label'] as String?,
        startTime: json['start_time'] as String,
        toleranceMinutes: json['tolerance_minutes'] as int? ?? 15,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  String get displayName => label?.isNotEmpty == true ? '$label — $startTime' : startTime;
}

class TrainingSession {
  final String id;
  final String academyId;
  final String? createdByUserId;
  final String? templateId;
  final String classDate;
  final String startTime;
  final int toleranceMinutes;
  final String? label;
  final String status;
  final String? openedAt;
  final String? closedAt;
  final String createdAt;
  final int preCheckinCount;

  TrainingSession({
    required this.id,
    required this.academyId,
    this.createdByUserId,
    this.templateId,
    required this.classDate,
    required this.startTime,
    required this.toleranceMinutes,
    this.label,
    required this.status,
    this.openedAt,
    this.closedAt,
    required this.createdAt,
    this.preCheckinCount = 0,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) => TrainingSession(
        id: json['id'] as String,
        academyId: json['academy_id'] as String,
        createdByUserId: json['created_by_user_id'] as String?,
        templateId: json['template_id'] as String?,
        classDate: json['class_date'] as String,
        startTime: json['start_time'] as String,
        toleranceMinutes: json['tolerance_minutes'] as int? ?? 15,
        label: json['label'] as String?,
        status: json['status'] as String,
        openedAt: json['opened_at'] as String?,
        closedAt: json['closed_at'] as String?,
        createdAt: json['created_at'] as String,
        preCheckinCount: json['pre_checkin_count'] as int? ?? 0,
      );

  String get displayName => label?.isNotEmpty == true ? '$label — $startTime' : startTime;

  bool get isUpcoming => status == 'upcoming';
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
}
