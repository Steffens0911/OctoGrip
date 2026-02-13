class Academy {
  final String id;
  final String name;
  final String? slug;
  final String? weeklyTheme;

  Academy({
    required this.id,
    required this.name,
    this.slug,
    this.weeklyTheme,
  });

  factory Academy.fromJson(Map<String, dynamic> json) {
    return Academy(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      weeklyTheme: json['weekly_theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'weekly_theme': weeklyTheme,
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
