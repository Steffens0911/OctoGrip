class Position {
  final String id;
  final String name;
  final String slug;
  final String? description;

  Position({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
      };
}
