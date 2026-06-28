class TrainingStats {
  final int workoutsLast30Days;
  final int? daysSinceLastWorkout;
  final int positionsLast30Days;
  final int positionsTotal;
  final double? avgTop10WorkoutsLast30Days;
  final double? avgTop10PositionsLast30Days;
  final int? rankingPositionsTotal;
  final int? rankingPositionsTotalOutOf;
  final int videosLast30Days;
  final double? avgTop10VideosLast30Days;
  final int? rankingVideosLast30Days;
  // novos
  final int videosTotal;
  final int? rankingVideosTotal;
  final int? rankingVideosTotalOutOf;
  final int trophiesTotal;
  final int totalXp;
  final int? rankingXp;
  final int? rankingXpOutOf;
  final int loginStreakCurrent;
  final int loginStreakBest;
  final int? rankingLoginStreak;
  final int? rankingLoginStreakOutOf;
  final int punctualityStreak;
  final int punctualityStreakBest;
  final int? rankingPunctuality;
  final int? rankingPunctualityOutOf;

  const TrainingStats({
    required this.workoutsLast30Days,
    this.daysSinceLastWorkout,
    required this.positionsLast30Days,
    required this.positionsTotal,
    this.avgTop10WorkoutsLast30Days,
    this.avgTop10PositionsLast30Days,
    this.rankingPositionsTotal,
    this.rankingPositionsTotalOutOf,
    required this.videosLast30Days,
    this.avgTop10VideosLast30Days,
    this.rankingVideosLast30Days,
    this.videosTotal = 0,
    this.rankingVideosTotal,
    this.rankingVideosTotalOutOf,
    this.trophiesTotal = 0,
    this.totalXp = 0,
    this.rankingXp,
    this.rankingXpOutOf,
    this.loginStreakCurrent = 0,
    this.loginStreakBest = 0,
    this.rankingLoginStreak,
    this.rankingLoginStreakOutOf,
    this.punctualityStreak = 0,
    this.punctualityStreakBest = 0,
    this.rankingPunctuality,
    this.rankingPunctualityOutOf,
  });

  factory TrainingStats.fromJson(Map<String, dynamic> json) => TrainingStats(
        workoutsLast30Days: (json['workouts_last_30_days'] as num).toInt(),
        daysSinceLastWorkout: json['days_since_last_workout'] as int?,
        positionsLast30Days: (json['positions_last_30_days'] as num).toInt(),
        positionsTotal: (json['positions_total'] as num).toInt(),
        avgTop10WorkoutsLast30Days:
            (json['avg_top10_workouts_last_30_days'] as num?)?.toDouble(),
        avgTop10PositionsLast30Days:
            (json['avg_top10_positions_last_30_days'] as num?)?.toDouble(),
        rankingPositionsTotal: json['ranking_positions_total'] as int?,
        rankingPositionsTotalOutOf:
            json['ranking_positions_total_out_of'] as int?,
        videosLast30Days: (json['videos_last_30_days'] as num? ?? 0).toInt(),
        avgTop10VideosLast30Days:
            (json['avg_top10_videos_last_30_days'] as num?)?.toDouble(),
        rankingVideosLast30Days: json['ranking_videos_last_30_days'] as int?,
        videosTotal: (json['videos_total'] as num? ?? 0).toInt(),
        rankingVideosTotal: json['ranking_videos_total'] as int?,
        rankingVideosTotalOutOf: json['ranking_videos_total_out_of'] as int?,
        trophiesTotal: (json['trophies_total'] as num? ?? 0).toInt(),
        totalXp: (json['total_xp'] as num? ?? 0).toInt(),
        rankingXp: json['ranking_xp'] as int?,
        rankingXpOutOf: json['ranking_xp_out_of'] as int?,
        loginStreakCurrent: (json['login_streak_current'] as num? ?? 0).toInt(),
        loginStreakBest: (json['login_streak_best'] as num? ?? 0).toInt(),
        rankingLoginStreak: json['ranking_login_streak'] as int?,
        rankingLoginStreakOutOf: json['ranking_login_streak_out_of'] as int?,
        punctualityStreak: (json['punctuality_streak'] as num? ?? 0).toInt(),
        punctualityStreakBest:
            (json['punctuality_streak_best'] as num? ?? 0).toInt(),
        rankingPunctuality: json['ranking_punctuality'] as int?,
        rankingPunctualityOutOf: json['ranking_punctuality_out_of'] as int?,
      );
}
