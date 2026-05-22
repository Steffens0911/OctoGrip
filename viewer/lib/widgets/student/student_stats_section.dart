import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Grid 2×2 de estatísticas do aluno — layout horizontal: ícone | número + label.
class StudentStatsSection extends StatelessWidget {
  const StudentStatsSection({super.key, required this.stats});

  final TrainingStats stats;

  @override
  Widget build(BuildContext context) {
    final accent = FantasyTheme.accentOf(context);
    final days = stats.daysSinceLastWorkout;

    final Color absenceColor;
    final IconData absenceIcon;
    if (days == null || days == 0) {
      absenceColor = accent;
      absenceIcon = days == 0 ? Icons.check_circle_rounded : Icons.calendar_today_rounded;
    } else if (days >= 15) {
      absenceColor = const Color(0xFFE0534A);
      absenceIcon = Icons.warning_amber_rounded;
    } else {
      absenceColor = const Color(0xFFF0923B);
      absenceIcon = Icons.calendar_today_rounded;
    }

    final String absenceValue = days == null ? '—' : (days == 0 ? 'Hoje!' : '$days');
    final String absenceLabel = days == null
        ? 'sem treinos registrados'
        : days == 0
            ? 'treinou hoje 💪'
            : days == 1
                ? 'dia sem treinar'
                : 'dias sem treinar';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.fitness_center_rounded,
                iconColor: accent,
                value: '${stats.workoutsLast30Days}',
                label: 'treinos nos últimos 30 dias',
                comparison: stats.avgTop10WorkoutsLast30Days,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: absenceIcon,
                iconColor: absenceColor,
                value: absenceValue,
                label: absenceLabel,
                valueColor: days != null && days > 0 ? absenceColor : null,
                highlightBorder: days == 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.sports_kabaddi_rounded,
                iconColor: accent,
                value: '${stats.positionsLast30Days}',
                label: 'posições executadas nos últimos 30 dias',
                comparison: stats.avgTop10PositionsLast30Days,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.military_tech_rounded,
                iconColor: const Color(0xFFD4A017),
                value: '${stats.positionsTotal}',
                label: 'posições executadas no total',
                ranking: stats.rankingPositionsTotal,
                rankingOutOf: stats.rankingPositionsTotalOutOf,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatCard(
          icon: Icons.play_circle_outline_rounded,
          iconColor: const Color(0xFF4A90D9),
          value: '${stats.videosLast30Days}',
          label: 'vídeos diários assistidos nos últimos 30 dias',
          comparison: stats.avgTop10VideosLast30Days,
          ranking: stats.rankingVideosLast30Days,
          rankingOutOf: stats.rankingPositionsTotalOutOf,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
    this.highlightBorder = false,
    this.comparison,
    this.ranking,
    this.rankingOutOf,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;
  final bool highlightBorder;
  final double? comparison;
  final int? ranking;
  final int? rankingOutOf;

  @override
  Widget build(BuildContext context) {
    final decoration = highlightBorder
        ? BoxDecoration(
            color: iconColor.withValues(alpha: 0.07),
            borderRadius: FantasyTheme.cardBorderRadius,
            border: Border.all(color: iconColor.withValues(alpha: 0.35)),
            boxShadow: FantasyTheme.cardShadowOf(context),
          )
        : FantasyTheme.cardBoxDecoration(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: decoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: valueColor ?? AppTheme.textPrimaryOf(context),
                        height: 1,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 10,
                        height: 1.2,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comparison != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'média top 10: ${comparison!.toStringAsFixed(comparison! % 1 == 0 ? 0 : 1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMutedOf(context),
                          fontSize: 9.5,
                        ),
                  ),
                ],
                if (ranking != null && rankingOutOf != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '#$ranking de $rankingOutOf na academia',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMutedOf(context),
                          fontSize: 9.5,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
