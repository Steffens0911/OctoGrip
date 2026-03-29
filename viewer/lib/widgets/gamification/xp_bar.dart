import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';

/// Barra de progresso de XP / nível (estilo gamificação), alinhada a [AppTheme].
class XPBar extends StatelessWidget {
  const XPBar({
    super.key,
    required this.progress,
    this.incrementLabel,
    this.levelLabel,
    this.height = 12,
  });

  /// Fração 0..1 do nível atual.
  final double progress;

  /// Texto opcional acima (ex.: "+25 XP").
  final String? incrementLabel;

  /// Texto opcional abaixo (ex.: "Nível 3").
  final String? levelLabel;

  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final primary = Theme.of(context).colorScheme.primary;
    final track = AppTheme.borderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (incrementLabel != null && incrementLabel!.isNotEmpty) ...[
          Text(
            incrementLabel!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: track.withValues(alpha: 0.35)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: clamped,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary,
                          Color.lerp(primary, AppTheme.primaryLight, 0.35)!,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (levelLabel != null && levelLabel!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            levelLabel!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
        ],
      ],
    );
  }
}
