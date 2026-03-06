class Academy {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? scheduleImageUrl;
  final String? weeklyTheme;
  final String? weeklyTechniqueId;
  final String? weeklyTechniqueName;
  final String? weeklyTechnique2Id;
  final String? weeklyTechnique2Name;
  final String? weeklyTechnique3Id;
  final String? weeklyTechnique3Name;
  final String? visibleLessonId;
  final String? visibleLessonName;
  final int weeklyMultiplier1;
  final int weeklyMultiplier2;
  final int weeklyMultiplier3;
  final bool showTrophies;
  final bool showPartners;
  final bool showSchedule;
  final bool showGlobalSupporters;
  final String? updatedAt;

  Academy({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.scheduleImageUrl,
    this.weeklyTheme,
    this.weeklyTechniqueId,
    this.weeklyTechniqueName,
    this.weeklyTechnique2Id,
    this.weeklyTechnique2Name,
    this.weeklyTechnique3Id,
    this.weeklyTechnique3Name,
    this.visibleLessonId,
    this.visibleLessonName,
    this.weeklyMultiplier1 = 1,
    this.weeklyMultiplier2 = 1,
    this.weeklyMultiplier3 = 1,
    this.showTrophies = true,
    this.showPartners = true,
    this.showSchedule = true,
    this.showGlobalSupporters = true,
    this.updatedAt,
  });

  factory Academy.fromJson(Map<String, dynamic> json) {
    return Academy(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      logoUrl: json['logo_url'] as String?,
      scheduleImageUrl: json['schedule_image_url'] as String?,
      weeklyTheme: json['weekly_theme'] as String?,
      weeklyTechniqueId: json['weekly_technique_id'] as String?,
      weeklyTechniqueName: json['weekly_technique_name'] as String?,
      weeklyTechnique2Id: json['weekly_technique_2_id'] as String?,
      weeklyTechnique2Name: json['weekly_technique_2_name'] as String?,
      weeklyTechnique3Id: json['weekly_technique_3_id'] as String?,
      weeklyTechnique3Name: json['weekly_technique_3_name'] as String?,
      visibleLessonId: json['visible_lesson_id'] as String?,
      visibleLessonName: json['visible_lesson_name'] as String?,
      weeklyMultiplier1: json['weekly_multiplier_1'] as int? ?? 1,
      weeklyMultiplier2: json['weekly_multiplier_2'] as int? ?? 1,
      weeklyMultiplier3: json['weekly_multiplier_3'] as int? ?? 1,
      showTrophies: json['show_trophies'] as bool? ?? true,
      showPartners: json['show_partners'] as bool? ?? true,
      showSchedule: json['show_schedule'] as bool? ?? true,
      showGlobalSupporters: json['show_global_supporters'] as bool? ?? true,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'logo_url': logoUrl,
        'schedule_image_url': scheduleImageUrl,
        'weekly_theme': weeklyTheme,
        'weekly_technique_id': weeklyTechniqueId,
        'weekly_technique_2_id': weeklyTechnique2Id,
        'weekly_technique_3_id': weeklyTechnique3Id,
        'show_trophies': showTrophies,
        'show_partners': showPartners,
        'show_schedule': showSchedule,
        'show_global_supporters': showGlobalSupporters,
        'updated_at': updatedAt,
      };
}

/// Uma posição no ranking (GET /academies/{id}/ranking).
class AcademyRankingEntry {
  final int rank;
  final String userId;
  final String? name;
  final int completionsCount;

  AcademyRankingEntry({
    required this.rank,
    required this.userId,
    this.name,
    required this.completionsCount,
  });

  factory AcademyRankingEntry.fromJson(Map<String, dynamic> json) {
    return AcademyRankingEntry(
      rank: json['rank'] as int,
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      completionsCount: json['completions_count'] as int,
    );
  }
}

/// Posição com quantidade de feedbacks de dificuldade (GET /academies/{id}/difficulties).
class AcademyDifficultyEntry {
  final String positionId;
  final String positionName;
  final int count;

  AcademyDifficultyEntry({
    required this.positionId,
    required this.positionName,
    required this.count,
  });

  factory AcademyDifficultyEntry.fromJson(Map<String, dynamic> json) {
    return AcademyDifficultyEntry(
      positionId: json['position_id'] as String,
      positionName: json['position_name'] as String,
      count: json['count'] as int,
    );
  }
}

/// Relatório semanal (GET /academies/{id}/report/weekly).
class AcademyWeeklyReport {
  final String academyId;
  final String weekStart;
  final String weekEnd;
  final int completionsCount;
  final int activeUsersCount;
  final List<AcademyRankingEntry> entries;

  AcademyWeeklyReport({
    required this.academyId,
    required this.weekStart,
    required this.weekEnd,
    required this.completionsCount,
    required this.activeUsersCount,
    required this.entries,
  });

  factory AcademyWeeklyReport.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>?)
        ?.map((e) => AcademyRankingEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return AcademyWeeklyReport(
      academyId: json['academy_id'] as String,
      weekStart: json['week_start'] as String,
      weekEnd: json['week_end'] as String,
      completionsCount: json['completions_count'] as int,
      activeUsersCount: json['active_users_count'] as int,
      entries: entries,
    );
  }
}
