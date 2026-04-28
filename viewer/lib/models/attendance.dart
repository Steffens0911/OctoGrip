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
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
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
  final bool faceRecognition;

  AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.checkedInAt,
    required this.method,
    required this.faceRecognition,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      method: json['method'] as String? ?? 'qr',
      faceRecognition: json['face_recognition'] as bool? ?? false,
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
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }
}

/// Estatística de sessão (minhas sessões / frequência).
class AttendanceSessionStatModel {
  final String id;
  final String? title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String status;
  final int presentCount;

  AttendanceSessionStatModel({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.presentCount,
  });

  factory AttendanceSessionStatModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionStatModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Linha de frequência por aluno (lista agregada).
class AttendanceStudentStatModel {
  final String userId;
  final String email;
  final String? name;
  final String? graduation;
  final int presentCount;
  final int totalSessions;
  final double attendanceRate;
  final DateTime? lastSeenAt;

  AttendanceStudentStatModel({
    required this.userId,
    required this.email,
    required this.name,
    required this.graduation,
    required this.presentCount,
    required this.totalSessions,
    required this.attendanceRate,
    required this.lastSeenAt,
  });

  factory AttendanceStudentStatModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStudentStatModel(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      graduation: json['graduation'] as String?,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }
}

/// Presença com dados da sessão (detalhe do aluno).
class AttendanceRecordWithSessionModel {
  final String id;
  final String sessionId;
  final String? sessionTitle;
  final DateTime sessionStartsAt;
  final DateTime checkedInAt;
  final String method;

  AttendanceRecordWithSessionModel({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionStartsAt,
    required this.checkedInAt,
    required this.method,
  });

  factory AttendanceRecordWithSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordWithSessionModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      sessionTitle: json['session_title'] as String?,
      sessionStartsAt: DateTime.parse(json['session_starts_at'] as String),
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      method: json['method'] as String? ?? 'qr',
    );
  }
}

/// Detalhe de frequência de um aluno + lista de presenças.
class AttendanceStudentDetailModel {
  final String userId;
  final String email;
  final String? name;
  final String? graduation;
  final int presentCount;
  final int totalSessions;
  final double attendanceRate;
  final DateTime? lastSeenAt;
  final List<AttendanceRecordWithSessionModel> records;

  AttendanceStudentDetailModel({
    required this.userId,
    required this.email,
    required this.name,
    required this.graduation,
    required this.presentCount,
    required this.totalSessions,
    required this.attendanceRate,
    required this.lastSeenAt,
    required this.records,
  });

  factory AttendanceStudentDetailModel.fromJson(Map<String, dynamic> json) {
    final raw = json['records'] as List<dynamic>? ?? const [];
    return AttendanceStudentDetailModel(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      graduation: json['graduation'] as String?,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      records: raw
          .map((e) => AttendanceRecordWithSessionModel.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Bucket de presenças (semana/mês) para gráfico — `GET /attendance/stats/me`.
class AttendancePeriodBucketModel {
  final DateTime periodStart;
  final DateTime periodEnd;
  final String label;
  final int presentCount;

  AttendancePeriodBucketModel({
    required this.periodStart,
    required this.periodEnd,
    required this.label,
    required this.presentCount,
  });

  factory AttendancePeriodBucketModel.fromJson(Map<String, dynamic> json) {
    return AttendancePeriodBucketModel(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      label: json['label'] as String,
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resposta agregada de frequência do utilizador logado — `GET /attendance/stats/me`.
class AttendanceMyStatsModel {
  final DateTime fromDate;
  final DateTime toDate;
  final String bucket;
  final int totalSessions;
  final int totalCheckins;
  final double percentage;
  final DateTime? lastSeenAt;
  final int lifetimeTotalSessions;
  final int lifetimeTotalCheckins;
  final double lifetimePercentage;
  final List<AttendancePeriodBucketModel> checkinsByPeriod;
  final List<AttendanceRecordWithSessionModel> history;
  final int historyTotal;
  final int historyLimit;
  final int historyOffset;

  AttendanceMyStatsModel({
    required this.fromDate,
    required this.toDate,
    required this.bucket,
    required this.totalSessions,
    required this.totalCheckins,
    required this.percentage,
    required this.lastSeenAt,
    required this.lifetimeTotalSessions,
    required this.lifetimeTotalCheckins,
    required this.lifetimePercentage,
    required this.checkinsByPeriod,
    required this.history,
    required this.historyTotal,
    required this.historyLimit,
    required this.historyOffset,
  });

  factory AttendanceMyStatsModel.fromJson(Map<String, dynamic> json) {
    final buckets = (json['checkins_by_period'] as List<dynamic>? ?? const [])
        .map((e) =>
            AttendancePeriodBucketModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final hist = (json['history'] as List<dynamic>? ?? const [])
        .map((e) => AttendanceRecordWithSessionModel.fromJson(
            e as Map<String, dynamic>))
        .toList();
    return AttendanceMyStatsModel(
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      bucket: json['bucket'] as String? ?? 'week',
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalCheckins: (json['total_checkins'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      lifetimeTotalSessions:
          (json['lifetime_total_sessions'] as num?)?.toInt() ?? 0,
      lifetimeTotalCheckins:
          (json['lifetime_total_checkins'] as num?)?.toInt() ?? 0,
      lifetimePercentage:
          (json['lifetime_percentage'] as num?)?.toDouble() ?? 0.0,
      checkinsByPeriod: buckets,
      history: hist,
      historyTotal: (json['history_total'] as num?)?.toInt() ?? 0,
      historyLimit: (json['history_limit'] as num?)?.toInt() ?? 30,
      historyOffset: (json['history_offset'] as num?)?.toInt() ?? 0,
    );
  }
}
