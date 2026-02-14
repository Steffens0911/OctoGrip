class Mission {
  final String id;
  final String techniqueId;
  final String startDate;
  final String endDate;
  final String level;
  final String? theme;
  final String? academyId;
  final bool isActive;

  Mission({
    required this.id,
    required this.techniqueId,
    required this.startDate,
    required this.endDate,
    required this.level,
    this.theme,
    this.academyId,
    this.isActive = true,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      techniqueId: json['technique_id'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      level: json['level'] as String,
      theme: json['theme'] as String?,
      academyId: json['academy_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'technique_id': techniqueId,
        'start_date': startDate,
        'end_date': endDate,
        'level': level,
        'theme': theme,
        'academy_id': academyId,
        'is_active': isActive,
      };
}
