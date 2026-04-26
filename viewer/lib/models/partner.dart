/// Parceiro da academia (divulgação para alunos).
class Partner {
  final String id;
  final String academyId;
  final String name;
  final String? description;
  final String? url;
  final String? logoUrl;
  final bool highlightOnLogin;
  final bool isActive;
  final bool isFeatured;
  final int? featuredOrder;
  final String? offerText;
  final String? externalUrl;

  Partner({
    required this.id,
    required this.academyId,
    required this.name,
    this.description,
    this.url,
    this.logoUrl,
    this.highlightOnLogin = false,
    this.isActive = true,
    this.isFeatured = false,
    this.featuredOrder,
    this.offerText,
    this.externalUrl,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as String,
      academyId: json['academy_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      url: json['url'] as String?,
      logoUrl: json['logo_url'] as String?,
      highlightOnLogin: json['highlight_on_login'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      featuredOrder: json['featured_order'] as int?,
      offerText: json['offer_text'] as String?,
      externalUrl: json['external_url'] as String?,
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
      'highlight_on_login': highlightOnLogin,
      'is_active': isActive,
      'is_featured': isFeatured,
      'featured_order': featuredOrder,
      'offer_text': offerText,
      'external_url': externalUrl,
    };
  }
}
