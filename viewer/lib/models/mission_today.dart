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

  Map<String, dynamic> toJson() => {
        if (missionId != null) 'mission_id': missionId,
        if (techniqueId != null) 'technique_id': techniqueId,
        if (lessonId != null) 'lesson_id': lessonId,
        'mission_title': missionTitle,
        'lesson_title': lessonTitle,
        'description': description,
        'video_url': videoUrl,
        'position_name': positionName,
        'technique_name': techniqueName,
        if (objective != null) 'objective': objective,
        if (estimatedDurationSeconds != null)
          'estimated_duration_seconds': estimatedDurationSeconds,
        if (weeklyTheme != null) 'weekly_theme': weeklyTheme,
        'is_review': isReview,
        'already_completed': alreadyCompleted,
        'multiplier': multiplier,
      };
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

  Map<String, dynamic> toJson() => {
        'period_label': periodLabel,
        if (mission != null) 'mission': mission!.toJson(),
      };
}

/// Opção de turma na semana. GET /mission_today/week (`available_kits` no JSON).
class WeeklyKitOption {
  final String kitId;
  final String label;
  final int itemCount;

  WeeklyKitOption({
    required this.kitId,
    required this.label,
    required this.itemCount,
  });

  factory WeeklyKitOption.fromJson(Map<String, dynamic> json) {
    return WeeklyKitOption(
      kitId: json['kit_id'] as String,
      label: json['label'] as String? ?? '',
      itemCount: json['item_count'] as int? ?? 0,
    );
  }
}

/// Resposta GET /mission_today/week — modo legado (até 3 slots) ou kits (1–5 por kit escolhido).
class MissionWeek {
  final List<MissionWeekSlot> entries;
  final bool needsKitChoice;
  final List<WeeklyKitOption> availableKits;
  final String? selectedKitId;

  MissionWeek({
    required this.entries,
    this.needsKitChoice = false,
    this.availableKits = const [],
    this.selectedKitId,
  });

  factory MissionWeek.fromJson(Map<String, dynamic> json) {
    final list = (json['entries'] as List<dynamic>?) ?? [];
    final kitsRaw = json['available_kits'] as List<dynamic>? ?? [];
    return MissionWeek(
      entries: list.map((e) => MissionWeekSlot.fromJson(e as Map<String, dynamic>)).toList(),
      needsKitChoice: json['needs_kit_choice'] as bool? ?? false,
      availableKits: kitsRaw
          .map((e) => WeeklyKitOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedKitId: json['selected_kit_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'needs_kit_choice': needsKitChoice,
        'available_kits': availableKits
            .map((k) => <String, dynamic>{
                  'kit_id': k.kitId,
                  'label': k.label,
                  'item_count': k.itemCount,
                })
            .toList(),
        'selected_kit_id': selectedKitId,
      };
}
