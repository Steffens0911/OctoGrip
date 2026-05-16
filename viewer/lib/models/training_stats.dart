class TrainingStats {
  final int workoutsLast30Days;
  final int? daysSinceLastWorkout;
  final int positionsLast30Days;
  final int positionsTotal;
  final double? avgTop10WorkoutsLast30Days;
  final double? avgTop10PositionsLast30Days;
  final int? rankingPositionsTotal;
  final int? rankingPositionsTotalOutOf;

  const TrainingStats({
    required this.workoutsLast30Days,
    this.daysSinceLastWorkout,
    required this.positionsLast30Days,
    required this.positionsTotal,
    this.avgTop10WorkoutsLast30Days,
    this.avgTop10PositionsLast30Days,
    this.rankingPositionsTotal,
    this.rankingPositionsTotalOutOf,
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
        rankingPositionsTotal:
            json['ranking_positions_total'] as int?,
        rankingPositionsTotalOutOf:
            json['ranking_positions_total_out_of'] as int?,
      );
}
