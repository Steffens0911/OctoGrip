import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

/// Fundo em gradiente estilo jogo (marrom) ou cor do tema (premium).
/// No estilo premium usa o scaffoldBackgroundColor do tema.
class GameBackground extends StatelessWidget {
  final Widget? child;

  const GameBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGameStyle =
        theme.extension<AppThemeStyleExtension>()?.isGameStyle ?? true;

    // Estilo jogo: claro = fundo liso coffee; escuro = gradiente marrom original.
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

    // Estilo premium: gradiente suave claro/escuro baseado no tema.
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
