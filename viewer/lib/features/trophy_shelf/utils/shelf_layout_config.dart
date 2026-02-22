/// Configuração de layout da estante: slots por linha, número de linhas, tamanhos.
/// Ajustável por breakpoint para responsividade.
class ShelfLayoutConfig {
  final int slotsPerRow;
  final int rowCount;
  final double slotSize;
  final double horizontalPadding;
  final double rowSpacing;
  final double topOffsetFraction;
  final double rowHeightFraction;

  const ShelfLayoutConfig({
    this.slotsPerRow = 4,
    this.rowCount = 3,
    this.slotSize = 72.0,
    this.horizontalPadding = 24.0,
    this.rowSpacing = 16.0,
    this.topOffsetFraction = 0.12,
    this.rowHeightFraction = 0.22,
  });

  /// Config para telas estreitas (phone portrait).
  static ShelfLayoutConfig forPhone(double width) {
    final slotSize = (width - 48) / 4 - 8;
    return ShelfLayoutConfig(
      slotsPerRow: 4,
      rowCount: 3,
      slotSize: slotSize.clamp(56.0, 88.0),
      horizontalPadding: 24.0,
      rowSpacing: 12.0,
      topOffsetFraction: 0.10,
      rowHeightFraction: 0.24,
    );
  }

  /// Config para telas largas (tablet / landscape).
  static ShelfLayoutConfig forTablet(double width) {
    final slotSize = (width - 80) / 5 - 8;
    return ShelfLayoutConfig(
      slotsPerRow: 5,
      rowCount: 4,
      slotSize: slotSize.clamp(64.0, 100.0),
      horizontalPadding: 40.0,
      rowSpacing: 20.0,
      topOffsetFraction: 0.08,
      rowHeightFraction: 0.20,
    );
  }

  /// Retorna config adequada ao tamanho da tela.
  static ShelfLayoutConfig fromWidth(double width) {
    if (width >= 600) return ShelfLayoutConfig.forTablet(width);
    return ShelfLayoutConfig.forPhone(width);
  }
}
