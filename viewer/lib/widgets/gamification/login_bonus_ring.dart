import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:viewer/core/gamification_constants.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Progresso visual até ao próximo bónus de sequência de login (múltiplo de 7 dias).
///
/// [streakDays] vem de `login_streak_days` em `/auth/me`. Múltiplos de 7 mostram anel
/// completo (ciclo concluído até ao bónus); caso contrário, `streak % 7 / 7`.
double streakProgressToNextBonus(int streakDays) {
  if (streakDays <= 0) return 0.0;
  const interval = kLoginStreakBonusIntervalDays;
  final r = streakDays % interval;
  if (r == 0) return 1.0;
  return r / interval;
}

/// Anel estilo “gauge” (fundo escuro, progresso menta), centro com valor do bónus em pontos.
///
/// O toque abre o detalhe das regras (ex. [showPointsRulesSheet]).
class LoginBonusRing extends StatelessWidget {
  const LoginBonusRing({
    super.key,
    required this.streakDays,
    this.onTap,
    this.size = 76,
  });

  final int streakDays;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = streakProgressToNextBonus(streakDays);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mint = Color(0xFF76FFB6);
    final trackColor = isDark
        ? const Color(0xFF3D3D45)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    final diskColor = isDark
        ? const Color(0xFF2B2B2B)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final accent = isDark ? mint : FantasyTheme.xpGreen;

    return Tooltip(
      message: 'Toque para ver como funcionam os pontos e o bónus de login',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _SegmentedRingPainter(
                progress: progress,
                trackColor: trackColor,
                diskColor: diskColor,
                accentColor: accent,
                strokeWidth: math.max(4.0, size * 0.07),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$kLoginStreakBonusPoints',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accent,
                              fontSize: size * 0.22,
                              height: 1.0,
                            ),
                      ),
                      Text(
                        'PTS',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: accent.withValues(alpha: 0.9),
                              fontSize: size * 0.11,
                              height: 1.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedRingPainter extends CustomPainter {
  _SegmentedRingPainter({
    required this.progress,
    required this.trackColor,
    required this.diskColor,
    required this.accentColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color diskColor;
  final Color accentColor;
  final double strokeWidth;

  static const int _segments = 32;
  static const double _gapRad = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final midR = outerR - strokeWidth / 2;

    final diskPaint = Paint()..color = diskColor;
    final innerDiskR = (midR - strokeWidth * 0.55).clamp(4.0, midR);
    canvas.drawCircle(c, innerDiskR, diskPaint);

    final rect = Rect.fromCircle(center: c, radius: midR);
    const start = -math.pi / 2;
    const sweepPer = (2 * math.pi) / _segments;
    final filled = (progress * _segments).round().clamp(0, _segments);

    const a1 = sweepPer - 2 * _gapRad;
    for (var i = 0; i < _segments; i++) {
      final a0 = start + i * sweepPer + _gapRad;
      if (a1 <= 0) continue;
      final p = Paint()
        ..color = i < filled ? accentColor : trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, a0, a1, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.diskColor != diskColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
