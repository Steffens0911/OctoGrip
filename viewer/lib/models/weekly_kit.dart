/// Item de uma turma semanal (API: GET/PATCH …/weekly-kits).
class WeeklyKitItemRead {
  final int orderIndex;
  final String techniqueId;
  final String? techniqueName;
  final int multiplier;

  WeeklyKitItemRead({
    required this.orderIndex,
    required this.techniqueId,
    this.techniqueName,
    required this.multiplier,
  });

  factory WeeklyKitItemRead.fromJson(Map<String, dynamic> json) {
    return WeeklyKitItemRead(
      orderIndex: json['order_index'] as int? ?? 0,
      techniqueId: json['technique_id'] as String,
      techniqueName: json['technique_name'] as String?,
      multiplier: json['multiplier'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_index': orderIndex,
        'technique_id': techniqueId,
        if (techniqueName != null) 'technique_name': techniqueName,
        'multiplier': multiplier,
      };
}

class WeeklyKitRead {
  final String id;
  final String academyId;
  final String label;
  final int sortOrder;
  final List<WeeklyKitItemRead> items;

  WeeklyKitRead({
    required this.id,
    required this.academyId,
    required this.label,
    required this.sortOrder,
    required this.items,
  });

  factory WeeklyKitRead.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return WeeklyKitRead(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      label: json['label'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      items: raw.map((e) => WeeklyKitItemRead.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
