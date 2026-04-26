/// Parceiro global exibido no banner da Central.
class GlobalPartner {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? offerText;
  final String? externalUrl;
  final String? buttonLabel;
  final int? featuredOrder;
  final bool isActive;

  const GlobalPartner({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.offerText,
    this.externalUrl,
    this.buttonLabel,
    this.featuredOrder,
    this.isActive = true,
  });

  factory GlobalPartner.fromJson(Map<String, dynamic> json) {
    return GlobalPartner(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      offerText: json['offer_text'] as String?,
      externalUrl: json['external_url'] as String?,
      buttonLabel: json['button_label'] as String?,
      featuredOrder: json['featured_order'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
