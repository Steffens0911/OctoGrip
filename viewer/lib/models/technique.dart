class Technique {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? videoUrl;
  final String fromPositionId;
  final String toPositionId;

  Technique({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.videoUrl,
    required this.fromPositionId,
    required this.toPositionId,
  });

  factory Technique.fromJson(Map<String, dynamic> json) {
    return Technique(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      fromPositionId: json['from_position_id'] as String,
      toPositionId: json['to_position_id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'video_url': videoUrl,
        'from_position_id': fromPositionId,
        'to_position_id': toPositionId,
      };
}
