/// DTO espelhando o contrato JSON da API + [academyId] para cache local.
class TechniqueDto {
  const TechniqueDto({
    required this.id,
    required this.academyId,
    required this.name,
    required this.slug,
    this.description,
    this.videoUrl,
  });

  final String id;
  final String academyId;
  final String name;
  final String slug;
  final String? description;
  final String? videoUrl;

  factory TechniqueDto.fromJson(
    Map<String, dynamic> json, {
    required String academyId,
  }) {
    return TechniqueDto(
      id: json['id'] as String,
      academyId: academyId,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'academy_id': academyId,
        'name': name,
        'slug': slug,
        'description': description,
        'video_url': videoUrl,
      };

  factory TechniqueDto.fromHiveMap(Map<dynamic, dynamic> map) {
    return TechniqueDto(
      id: map['id'] as String,
      academyId: map['academy_id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      videoUrl: map['video_url'] as String?,
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'id': id,
        'academy_id': academyId,
        'name': name,
        'slug': slug,
        'description': description,
        'video_url': videoUrl,
      };
}
