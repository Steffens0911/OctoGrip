import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/widgets/gamification/xp_bar.dart';

/// Diálogo de recompensa após concluir missão/lição.
///
/// [xpGained] deve refletir `points_awarded` devolvido por POST `/mission_complete` ou
/// `/lesson_complete` quando disponível; a barra de nível usa GET `/users/{id}/points`
/// após o sucesso. [xpFootnote] opcional (ex. aviso de estimativa se a API antiga não
/// enviar o campo).
class RewardScreen extends StatelessWidget {
  const RewardScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.xpGained,
    required this.level,
    required this.levelProgressFraction,
    required this.levelPointsInLevel,
    required this.nextThreshold,
    this.xpFootnote,
  });

  final String title;
  final String subtitle;
  final int xpGained;
  final int level;
  final double levelProgressFraction;
  final int levelPointsInLevel;
  final int nextThreshold;
  final String? xpFootnote;

  /// Exibe o diálogo e devolve quando é fechado (botão ou fora).
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required int xpGained,
    required int level,
    required double levelProgressFraction,
    required int levelPointsInLevel,
    required int nextThreshold,
    String? xpFootnote,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RewardScreen(
        title: title,
        subtitle: subtitle ?? 'Continue assim!',
        xpGained: xpGained,
        level: level,
        levelProgressFraction: levelProgressFraction,
        levelPointsInLevel: levelPointsInLevel,
        nextThreshold: nextThreshold,
        xpFootnote: xpFootnote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 700);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  seed: xpGained * 17 + level * 31,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: xpGained),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Text(
                        '+$value XP',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                      );
                    },
                  ),
                  if (xpFootnote != null && xpFootnote!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      xpFootnote!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textMutedOf(context),
                          ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  XPBar(
                    progress: levelProgressFraction,
                    levelLabel:
                        'Nível $level · $levelPointsInLevel / $nextThreshold XP no nível',
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final colors = <Color>[
      AppTheme.primary,
      AppTheme.primaryLight,
      AppTheme.accent,
    ];
    final paint = Paint();
    for (var i = 0; i < 28; i++) {
      paint.color = colors[i % colors.length]
          .withValues(alpha: 0.22 + rnd.nextDouble() * 0.28);
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.55;
      final r = 2.5 + rnd.nextDouble() * 6;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
