/// Anúncio do marketplace da academia (API admin e leitura aluno).
class MarketplaceItem {
  final String id;
  final String? academyId;
  final String? academyName;
  final String title;
  final String? description;
  final int priceCents;
  final String currency;
  final String? imageUrl;
  /// URL `wa.me` calculada na API; null se o anúncio não tiver WhatsApp.
  final String? whatsappUrl;
  final String? whatsappDdd;
  final String? whatsappNumber;
  final int? sortOrder;
  final bool isActive;
  final int whatsappClicks;

  const MarketplaceItem({
    required this.id,
    this.academyId,
    this.academyName,
    required this.title,
    this.description,
    required this.priceCents,
    this.currency = 'BRL',
    this.imageUrl,
    this.whatsappUrl,
    this.whatsappDdd,
    this.whatsappNumber,
    this.sortOrder,
    this.isActive = true,
    this.whatsappClicks = 0,
  });

  factory MarketplaceItem.fromStudentJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priceCents: json['price_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'BRL',
      imageUrl: json['image_url'] as String?,
      whatsappUrl: json['whatsapp_url'] as String?,
    );
  }

  factory MarketplaceItem.fromAdminJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['id'] as String,
      academyId: json['academy_id'] as String?,
      academyName: json['academy_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      priceCents: json['price_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'BRL',
      imageUrl: json['image_url'] as String?,
      whatsappUrl: json['whatsapp_url'] as String?,
      whatsappDdd: json['whatsapp_ddd'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      sortOrder: json['sort_order'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      whatsappClicks: json['whatsapp_clicks'] as int? ?? 0,
    );
  }
}
