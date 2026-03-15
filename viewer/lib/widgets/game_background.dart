import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/services/theme_service.dart';

/// Fundo em gradiente ou cor sólida conforme o estilo (jogo, premium, memo).
class GameBackground extends StatelessWidget {
  final Widget? child;

  const GameBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppThemeStyleExtension>()?.style ?? ThemeStyle.game;

    // Estilo memo: fundo sólido (N900) ou gradiente sutil.
    if (style == ThemeStyle.memo) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.scaffoldBackgroundColor,
        child: child,
      );
    }

    final isGameStyle = style == ThemeStyle.game;

    // Estilo jogo: claro = fundo liso; escuro = gradiente marrom.
    if (isGameStyle) {
      if (theme.brightness == Brightness.light) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: theme.scaffoldBackgroundColor,
          child: child,
        );
      }
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.shelfBrown,
              AppTheme.shelfBrownDark,
            ],
          ),
        ),
        child: child,
      );
    }

    // Estilo premium: gradiente suave.
    final scaffold = theme.scaffoldBackgroundColor;
    final surfaceHigh = theme.colorScheme.surfaceContainerHighest;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scaffold,
            surfaceHigh.withValues(alpha: 0.35),
            scaffold,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
