/// Motivos aceitos pela API de denúncia (`app/schemas/photo_moderation.py`).
const Map<String, String> kPhotoReportReasons = {
  'spam': 'Spam ou propaganda',
  'nudity': 'Nudez ou conteúdo sexual',
  'violence': 'Violência',
  'harassment': 'Assédio ou ofensa',
  'other': 'Outro motivo',
};

String photoReportReasonLabel(String reason) =>
    kPhotoReportReasons[reason] ?? 'Outro motivo';

class PhotoReport {
  const PhotoReport({
    required this.id,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.photoId,
    required this.targetType,
    this.details,
    this.reporterName,
    this.commentId,
    this.targetAuthorId,
    this.targetAuthorName,
    this.targetText,
    this.targetThumbnailUrl,
    this.targetRemoved = false,
    this.reportsOnTarget = 1,
  });

  final String id;
  final String status;
  final String reason;
  final String? details;
  final DateTime createdAt;
  final String? reporterName;
  final String photoId;
  final String? commentId;

  /// `photo` ou `comment`.
  final String targetType;
  final String? targetAuthorId;
  final String? targetAuthorName;
  final String? targetText;
  final String? targetThumbnailUrl;
  final bool targetRemoved;
  final int reportsOnTarget;

  bool get isComment => targetType == 'comment';
  bool get isOpen => status == 'open';

  factory PhotoReport.fromJson(Map<String, dynamic> json) {
    return PhotoReport(
      id: (json['id'] as String? ?? ''),
      status: (json['status'] as String? ?? 'open'),
      reason: (json['reason'] as String? ?? 'other'),
      details: json['details'] as String?,
      createdAt: (DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0)),
      reporterName: json['reporter_name'] as String?,
      photoId: (json['photo_id'] as String? ?? ''),
      commentId: json['comment_id'] as String?,
      targetType: (json['target_type'] as String? ?? 'photo'),
      targetAuthorId: json['target_author_id'] as String?,
      targetAuthorName: json['target_author_name'] as String?,
      targetText: json['target_text'] as String?,
      targetThumbnailUrl: json['target_thumbnail_url'] as String?,
      targetRemoved: (json['target_removed'] as bool? ?? false),
      reportsOnTarget: ((json['reports_on_target'] as num?)?.toInt() ?? 1),
    );
  }
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.createdAt,
    this.name,
    this.avatarUrl,
  });

  final String userId;
  final String? name;
  final String? avatarUrl;
  final DateTime createdAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: (json['user_id'] as String? ?? ''),
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: (DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0)),
    );
  }
}
