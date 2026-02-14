/// Item do histórico GET /mission_usages/history. Conclusão por missão pode ter lesson_id null.
class MissionHistoryItem {
  final String? lessonId;
  final String lessonTitle;
  final DateTime completedAt;
  final String usageType;

  MissionHistoryItem({
    this.lessonId,
    required this.lessonTitle,
    required this.completedAt,
    required this.usageType,
  });

  factory MissionHistoryItem.fromJson(Map<String, dynamic> json) {
    return MissionHistoryItem(
      lessonId: json['lesson_id'] as String?,
      lessonTitle: (json['lesson_title'] as String?) ?? '',
      completedAt: DateTime.parse((json['completed_at'] as String?) ?? ''),
      usageType: json['usage_type'] as String? ?? 'after_training',
    );
  }
}
