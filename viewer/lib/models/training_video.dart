class TrainingVideo {
  final String id;
  final String title;
  final String youtubeUrl;
  final int pointsPerDay;
  final bool isActive;
  final int? durationSeconds;
  final String? academyId;
  final String? academyName;
  final bool hasCompletedToday;
  final DateTime? lastCompletedAt;

  TrainingVideo({
    required this.id,
    required this.title,
    required this.youtubeUrl,
    required this.pointsPerDay,
    required this.isActive,
    this.durationSeconds,
    this.academyId,
    this.academyName,
    required this.hasCompletedToday,
    this.lastCompletedAt,
  });

  factory TrainingVideo.fromJson(Map<String, dynamic> json) {
    return TrainingVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      youtubeUrl: json['youtube_url'] as String,
      pointsPerDay: (json['points_per_day'] as num).toInt(),
      isActive: json['is_active'] as bool? ?? true,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      academyId: json['academy_id'] as String?,
      academyName: json['academy_name'] as String?,
      hasCompletedToday: json['has_completed_today'] as bool? ?? false,
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.tryParse(json['last_completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'youtube_url': youtubeUrl,
        'points_per_day': pointsPerDay,
        'is_active': isActive,
        'duration_seconds': durationSeconds,
        'academy_id': academyId,
        'academy_name': academyName,
      };
}

class TrainingVideoCompletionResult {
  final String trainingVideoId;
  final bool hasCompletedToday;
  final bool alreadyCompletedToday;
  final int? pointsGranted;
  final int? newPointsBalance;
  final String? message;

  TrainingVideoCompletionResult({
    required this.trainingVideoId,
    required this.hasCompletedToday,
    required this.alreadyCompletedToday,
    this.pointsGranted,
    this.newPointsBalance,
    this.message,
  });

  factory TrainingVideoCompletionResult.fromJson(Map<String, dynamic> json) {
    return TrainingVideoCompletionResult(
      trainingVideoId: json['training_video_id'] as String,
      hasCompletedToday: json['has_completed_today'] as bool? ?? false,
      alreadyCompletedToday: json['already_completed_today'] as bool? ?? false,
      pointsGranted: (json['points_granted'] as num?)?.toInt(),
      newPointsBalance: (json['new_points_balance'] as num?)?.toInt(),
      message: json['message'] as String?,
    );
  }
}

