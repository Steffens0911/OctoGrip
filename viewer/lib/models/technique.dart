class Technique {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? videoUrl;

  Technique({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.videoUrl,
  });

  factory Technique.fromJson(Map<String, dynamic> json) {
    return Technique(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'video_url': videoUrl,
      };
}
