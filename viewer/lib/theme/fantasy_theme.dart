import 'package:flutter/material.dart';

/// Cores e constantes do tema fantasia / academia medieval.
///
/// As constantes estáticas (`textPrimary`, `cardGradient`, etc.) descrevem o
/// modo **escuro** (paleta espacial). Em modo **claro**, use os métodos
/// `*Of(BuildContext)` para fundo, cartões, texto e sombras alinhados ao
/// [ThemeData] / [ColorScheme] (ex.: Memo), evitando blocos escuros no template claro.
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

  /// Texto/ícone sobre botão dourado (legível em claro e escuro).
  static const Color goldButtonForeground = Color(0xFF1A1F2E);

  // Verde para XP e seleção (barra, badge, nav selecionado)
  static const Color xpGreen = Color(0xFF49AB6C);
  static const Color xpGreenLight = Color(0xFF60D88B);

  // Texto (modo escuro; em claro use [textPrimaryOf] etc.)
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFC7C7D1);
  static const Color textMuted = Color(0xFF9A9AAA);

  // Barra de navegação
  static const Color navBackground = Color(0xFF1e1e2e);
  static const Color navSelectedBg = Color(0xFF2d3d2d);

  /// Gradiente de fundo da tela (modo escuro).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  /// Gradiente dos cards (modo escuro).
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardSurfaceTop, cardSurfaceBottom],
  );

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Fundo da área Missões (stack atrás do scroll): escuro = gradiente; claro = scaffold.
  static BoxDecoration missionHomeBackgroundDecoration(BuildContext context) {
    final theme = Theme.of(context);
    if (_isDark(context)) {
      return const BoxDecoration(gradient: backgroundGradient);
    }
    final cs = theme.colorScheme;
    final low = cs.surfaceContainerLowest;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.scaffoldBackgroundColor,
          Color.lerp(low, theme.scaffoldBackgroundColor, 0.65)!,
          theme.scaffoldBackgroundColor,
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
    );
  }

  /// Decoração dos cartões fantasia (Troféus, Parceiros, missões, agenda, mural).
  static BoxDecoration cardBoxDecoration(BuildContext context) {
    if (_isDark(context)) {
      return BoxDecoration(
        gradient: cardGradient,
        borderRadius: cardBorderRadius,
        boxShadow: cardShadow,
        border: Border.all(
          color: textMuted.withValues(alpha: 0.15),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: cardBorderRadius,
      boxShadow: cardShadowOf(context),
      border: Border.all(
        color: cs.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }

  /// Sombra dos cards (escuro = forte; claro = suave).
  static List<BoxShadow> cardShadowOf(BuildContext context) {
    if (_isDark(context)) return cardShadow;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// Sombra suave para cards (modo escuro).
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? textPrimary : Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryOf(BuildContext context) => _isDark(context)
      ? textSecondary
      : Theme.of(context).colorScheme.onSurfaceVariant;

  static Color textMutedOf(BuildContext context) => _isDark(context)
      ? textMuted
      : Theme.of(context).colorScheme.outline;

  /// Superfície “encaixada” (badge, avatar interno, trilho da barra XP).
  static Color insetSurfaceOf(BuildContext context) => _isDark(context)
      ? cardSurfaceTop
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  /// BorderRadius para cards (16–20).
  static const double cardRadius = 18;
  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  static const double buttonRadius = 12;
  static BorderRadius get buttonBorderRadius => BorderRadius.circular(buttonRadius);
}
