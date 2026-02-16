/// Resposta GET /mission_today — missão do dia pronta para exibição.
class MissionToday {
  final String? missionId;
  final String? techniqueId;
  final String? lessonId;
  final String missionTitle;
  final String lessonTitle;
  final String description;
  final String videoUrl;
  final String positionName;
  final String techniqueName;
  final String? objective;
  final int? estimatedDurationSeconds;
  final String? weeklyTheme;
  final bool isReview;
  final bool alreadyCompleted;
  final int multiplier;

  MissionToday({
    this.missionId,
    this.techniqueId,
    this.lessonId,
    required this.missionTitle,
    required this.lessonTitle,
    required this.description,
    required this.videoUrl,
    required this.positionName,
    required this.techniqueName,
    this.objective,
    this.estimatedDurationSeconds,
    this.weeklyTheme,
    this.isReview = false,
    this.alreadyCompleted = false,
    this.multiplier = 1,
  });

  factory MissionToday.fromJson(Map<String, dynamic> json) {
    return MissionToday(
      missionId: json['mission_id'] as String?,
      techniqueId: json['technique_id'] as String?,
      lessonId: json['lesson_id'] as String?,
      missionTitle: json['mission_title'] as String? ?? '',
      lessonTitle: json['lesson_title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      positionName: json['position_name'] as String? ?? '',
      techniqueName: json['technique_name'] as String? ?? '',
      objective: json['objective'] as String?,
      estimatedDurationSeconds: json['estimated_duration_seconds'] as int?,
      weeklyTheme: json['weekly_theme'] as String?,
      isReview: json['is_review'] as bool? ?? false,
      alreadyCompleted: json['already_completed'] as bool? ?? false,
      multiplier: json['multiplier'] as int? ?? 1,
    );
  }
}

/// Um slot da semana (Seg–Ter, Qua–Qui, Sex–Dom) com a missão opcional. GET /mission_today/week.
class MissionWeekSlot {
  final String periodLabel;
  final MissionToday? mission;

  MissionWeekSlot({required this.periodLabel, this.mission});

  factory MissionWeekSlot.fromJson(Map<String, dynamic> json) {
    final m = json['mission'];
    return MissionWeekSlot(
      periodLabel: json['period_label'] as String? ?? '',
      mission: m != null ? MissionToday.fromJson(m as Map<String, dynamic>) : null,
    );
  }
}

/// Resposta GET /mission_today/week — lista das 3 missões da semana.
class MissionWeek {
  final List<MissionWeekSlot> entries;

  MissionWeek({required this.entries});

  factory MissionWeek.fromJson(Map<String, dynamic> json) {
    final list = (json['entries'] as List<dynamic>?) ?? [];
    return MissionWeek(
      entries: list.map((e) => MissionWeekSlot.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
