import 'package:flutter/material.dart';

/// Tokens de design baseados em grid 8px (Memo UI Kit).
/// Use em todas as telas para espaçamento e radius consistentes.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 40;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingS = EdgeInsets.all(s);
  static const EdgeInsets paddingM = EdgeInsets.all(m);
  static const EdgeInsets paddingL = EdgeInsets.all(l);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalS = SizedBox(height: s);
  static const SizedBox verticalM = SizedBox(height: m);
  static const SizedBox verticalL = SizedBox(height: l);
  static const SizedBox verticalXl = SizedBox(height: xl);

  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalS = SizedBox(width: s);
  static const SizedBox horizontalM = SizedBox(width: m);
  static const SizedBox horizontalL = SizedBox(width: l);
}

/// Radius padronizado para cards, botões e inputs.
class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double button = 12;
  static const double input = 12;
  static const double tile = 12;
  static const double chip = 8;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get tileRadius => BorderRadius.circular(tile);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
}

/// Sombra sutil para cards (elevação leve).
class AppShadow {
  AppShadow._();

  static List<BoxShadow> card(BuildContext context) {
    return [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
