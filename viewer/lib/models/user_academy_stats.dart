class UserAcademyStats {
  final String userId;
  final int videosInPeriod;
  final int positionsInPeriod;
  final int workoutsInPeriod;
  final int trophiesCount;
  final int? daysSinceLastWorkout;

  const UserAcademyStats({
    required this.userId,
    required this.videosInPeriod,
    required this.positionsInPeriod,
    required this.workoutsInPeriod,
    required this.trophiesCount,
    this.daysSinceLastWorkout,
  });

  factory UserAcademyStats.fromJson(Map<String, dynamic> json) => UserAcademyStats(
        userId: json['user_id'] as String,
        videosInPeriod: (json['videos_in_period'] as num).toInt(),
        positionsInPeriod: (json['positions_in_period'] as num).toInt(),
        workoutsInPeriod: (json['workouts_in_period'] as num).toInt(),
        trophiesCount: (json['trophies_count'] as num).toInt(),
        daysSinceLastWorkout: json['days_since_last_workout'] as int?,
      );
}
