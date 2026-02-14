/// Resposta GET /metrics/usage.
class UsageMetrics {
  final int totalCompletions;
  final int completionsLast7Days;
  final int uniqueUsersCompleted;
  final int beforeTrainingCount;
  final int afterTrainingCount;
  final double beforeTrainingPercent;

  UsageMetrics({
    required this.totalCompletions,
    required this.completionsLast7Days,
    required this.uniqueUsersCompleted,
    this.beforeTrainingCount = 0,
    this.afterTrainingCount = 0,
    this.beforeTrainingPercent = 0.0,
  });

  factory UsageMetrics.fromJson(Map<String, dynamic> json) {
    return UsageMetrics(
      totalCompletions: (json['total_completions'] as num?)?.toInt() ?? 0,
      completionsLast7Days: (json['completions_last_7_days'] as num?)?.toInt() ?? 0,
      uniqueUsersCompleted: (json['unique_users_completed'] as num?)?.toInt() ?? 0,
      beforeTrainingCount: (json['before_training_count'] as num?)?.toInt() ?? 0,
      afterTrainingCount: (json['after_training_count'] as num?)?.toInt() ?? 0,
      beforeTrainingPercent: (json['before_training_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
