import 'package:flutter/material.dart';

/// Cores e constantes do tema fantasia / academia medieval.
/// Usado pela HomePage e widgets da tela de início fantasia.
class FantasyTheme {
  FantasyTheme._();

  // Fundo escuro (espacial / céu estrelado)
  static const Color backgroundTop = Color(0xFF1a1a2e);
  static const Color backgroundBottom = Color(0xFF16213e);

  // Superfície dos cards (gradiente: top mais escuro)
  static const Color cardSurfaceTop = Color(0xFF2a2a3e);
  static const Color cardSurfaceBottom = Color(0xFF343450);

  // Dourado para botões e detalhes
  static const Color gold = Color(0xFFD4A017);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFE8B82E);

  // Verde para XP e seleção (barra, badge, nav selecionado)
  static const Color xpGreen = Color(0xFF49AB6C);
  static const Color xpGreenLight = Color(0xFF60D88B);

  // Texto
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFC7C7D1);
  static const Color textMuted = Color(0xFF9A9AAA);

  // Barra de navegação
  static const Color navBackground = Color(0xFF1e1e2e);
  static const Color navSelectedBg = Color(0xFF2d3d2d);

  /// Gradiente de fundo da tela (fallback quando não há imagem).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  /// Gradiente dos cards (escuro, sutil).
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardSurfaceTop, cardSurfaceBottom],
  );

  /// Sombra suave para cards.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// BorderRadius para cards (16–20).
  static const double cardRadius = 18;
  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  static const double buttonRadius = 12;
  static BorderRadius get buttonBorderRadius => BorderRadius.circular(buttonRadius);
}
