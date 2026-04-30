import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';

/// Estilos partilhados do Campo de treinamento e cartões gamificados.
///
/// Alinhado ao tema Memo (painel Central): superfície plana, borda fina,
/// sombra suave e acentos via [ColorScheme.primary].
class FantasyTheme {
  FantasyTheme._();

  /// Fundo atrás do scroll do Campo de treinamento — contínuo com o shell Memo.
  static BoxDecoration missionHomeBackgroundDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(color: theme.scaffoldBackgroundColor);
  }

  /// Cartões (troféus, parceiros, missões, agenda, mural).
  static BoxDecoration cardBoxDecoration(BuildContext context) {
    return BoxDecoration(
      color: AppTheme.surfaceOf(context),
      borderRadius: AppRadius.cardRadius,
      border: Border.all(color: AppTheme.borderOf(context)),
      boxShadow: AppShadow.card(context),
    );
  }

  static List<BoxShadow> cardShadowOf(BuildContext context) =>
      AppShadow.card(context);

  /// Compatível com código antigo que esperava sombra forte em escuro.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static Color textPrimaryOf(BuildContext context) =>
      AppTheme.textPrimaryOf(context);

  static Color textSecondaryOf(BuildContext context) =>
      AppTheme.textSecondaryOf(context);

  static Color textMutedOf(BuildContext context) =>
      AppTheme.textMutedOf(context);

  /// Superfície encaixada (badge, avatar interno, trilhos).
  static Color insetSurfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  /// Raio dos cartões — igual ao kit Memo (`AppRadius.card`).
  static BorderRadius get cardBorderRadius => AppRadius.cardRadius;

  static const double cardRadius = AppRadius.card;

  static BorderRadius get buttonBorderRadius => AppRadius.buttonRadius;

  /// Acento principal (substitui o antigo dourado fixo).
  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color accentStrongOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.9);

  static Color accentShadowOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);

  /// Texto/ícone sobre botão preenchido com primary.
  static Color onAccentForegroundOf(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  /// Verde XP / seleção — alinhado ao primary Memo.
  static Color xpGreenOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
}
