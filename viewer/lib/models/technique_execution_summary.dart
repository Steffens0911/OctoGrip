class TechniqueExecutionSummary {
  final String? academyId;
  final int beforeTrainingCount;
  final int afterTrainingCount;
  final int total;
  final double beforeTrainingPercent;

  TechniqueExecutionSummary({
    required this.academyId,
    required this.beforeTrainingCount,
    required this.afterTrainingCount,
    required this.total,
    required this.beforeTrainingPercent,
  });

  factory TechniqueExecutionSummary.fromJson(Map<String, dynamic> json) {
    return TechniqueExecutionSummary(
      academyId: json['academy_id'] as String?,
      beforeTrainingCount: (json['before_training_count'] as num?)?.toInt() ?? 0,
      afterTrainingCount: (json['after_training_count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      beforeTrainingPercent: (json['before_training_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
