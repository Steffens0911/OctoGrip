class FaceArriveResponse {
  final bool matched;
  final double confidence;
  final String? studentId;
  final String? studentName;
  final bool? wasPunctual;
  final int? punctualityStreak;
  final int xpAwarded;
  final String greeting;
  final bool duplicate;

  const FaceArriveResponse({
    required this.matched,
    required this.confidence,
    required this.greeting,
    this.studentId,
    this.studentName,
    this.wasPunctual,
    this.punctualityStreak,
    this.xpAwarded = 0,
    this.duplicate = false,
  });

  factory FaceArriveResponse.fromJson(Map<String, dynamic> json) {
    return FaceArriveResponse(
      matched: json['matched'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String?,
      wasPunctual: json['was_punctual'] as bool?,
      punctualityStreak: (json['punctuality_streak'] as num?)?.toInt(),
      xpAwarded: (json['xp_awarded'] as num?)?.toInt() ?? 0,
      greeting: json['greeting'] as String? ?? '',
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }
}
