/// Parceiro da academia (divulgação para alunos).
class Partner {
  final String id;
  final String academyId;
  final String name;
  final String? description;
  final String? url;
  final String? logoUrl;

  Partner({
    required this.id,
    required this.academyId,
    required this.name,
    this.description,
    this.url,
    this.logoUrl,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      url: json['url'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'academy_id': academyId,
      'name': name,
      'description': description,
      'url': url,
      'logo_url': logoUrl,
    };
  }
}
