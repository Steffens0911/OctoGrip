class AttendanceSessionModel {
  final String id;
  final String? academyId;
  final String createdByUserId;
  final String status;
  final String? title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? expiresAt;
  final int presentCount;

  AttendanceSessionModel({
    required this.id,
    required this.academyId,
    required this.createdByUserId,
    required this.status,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.expiresAt,
    required this.presentCount,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      id: json['id'] as String,
      academyId: json['academy_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String,
      status: json['status'] as String? ?? 'active',
      title: json['title'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String userId;
  final DateTime checkedInAt;
  final String method;

  AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.checkedInAt,
    required this.method,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      method: json['method'] as String? ?? 'qr',
    );
  }
}

class AttendanceQrPayloadModel {
  final String payload;
  final DateTime expiresAt;

  AttendanceQrPayloadModel({required this.payload, required this.expiresAt});

  factory AttendanceQrPayloadModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrPayloadModel(
      payload: json['payload'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class AttendanceUserSummaryModel {
  final String userId;
  final DateTime fromDt;
  final DateTime toDt;
  final int presentCount;
  final DateTime? lastSeenAt;

  AttendanceUserSummaryModel({
    required this.userId,
    required this.fromDt,
    required this.toDt,
    required this.presentCount,
    required this.lastSeenAt,
  });

  factory AttendanceUserSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceUserSummaryModel(
      userId: json['user_id'] as String,
      fromDt: DateTime.parse(json['from_dt'] as String),
      toDt: DateTime.parse(json['to_dt'] as String),
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
    );
  }
}

