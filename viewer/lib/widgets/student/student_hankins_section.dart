import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/training_stats.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Seção de estatísticas comparativas do aluno (hankins) para a tela de pré-checkin.
/// Exibe 6 grupos de métricas com rankings na academia.
class StudentHankinsSection extends StatelessWidget {
  const StudentHankinsSection({super.key, required this.stats});

  final TrainingStats stats;

  @override
  Widget build(BuildContext context) {
    final accent = FantasyTheme.accentOf(context);
    final gold = const Color(0xFFD4A017);
    final blue = const Color(0xFF4A90D9);
    final green = const Color(0xFF27AE60);
    final purple = const Color(0xFF8E44AD);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Seus números',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
        ),
        // Técnicas executadas total + ranking
        _HankinCard(
          icon: Icons.sports_kabaddi_rounded,
          iconColor: accent,
          value: '${stats.positionsTotal}',
          label: 'técnicas executadas no total',
          ranking: stats.rankingPositionsTotal,
          rankingOutOf: stats.rankingPositionsTotalOutOf,
        ),
        const SizedBox(height: 8),
        // Login streak: atual + recorde + ranking
        Row(
          children: [
            Expanded(
              child: _HankinCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFE67E22),
                value: '${stats.loginStreakCurrent}',
                label: stats.loginStreakCurrent == 1 ? 'dia seguido logando' : 'dias seguidos logando',
                ranking: stats.rankingLoginStreak,
                rankingOutOf: stats.rankingLoginStreakOutOf,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HankinCard(
                icon: Icons.emoji_events_rounded,
                iconColor: gold,
                value: '${stats.loginStreakBest}',
                label: 'recorde de login seguido',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Pontualidade: atual + recorde + ranking
        Row(
          children: [
            Expanded(
              child: _HankinCard(
                icon: Icons.alarm_on_rounded,
                iconColor: green,
                value: '${stats.punctualityStreak}',
                label: stats.punctualityStreak == 1 ? 'treino pontual seguido' : 'treinos pontuais seguidos',
                ranking: stats.rankingPunctuality,
                rankingOutOf: stats.rankingPunctualityOutOf,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HankinCard(
                icon: Icons.military_tech_rounded,
                iconColor: gold,
                value: '${stats.punctualityStreakBest}',
                label: 'recorde de pontualidade',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Troféus
        _HankinCard(
          icon: Icons.workspace_premium_rounded,
          iconColor: gold,
          value: '${stats.trophiesTotal}',
          label: stats.trophiesTotal == 1 ? 'troféu conquistado' : 'troféus conquistados',
        ),
        const SizedBox(height: 8),
        // Vídeos assistidos all-time + ranking
        _HankinCard(
          icon: Icons.play_circle_outline_rounded,
          iconColor: blue,
          value: '${stats.videosTotal}',
          label: 'vídeos assistidos no total',
          ranking: stats.rankingVideosTotal,
          rankingOutOf: stats.rankingVideosTotalOutOf,
        ),
        const SizedBox(height: 8),
        // XP total + ranking
        _HankinCard(
          icon: Icons.bolt_rounded,
          iconColor: purple,
          value: '${stats.totalXp}',
          label: 'XP acumulado',
          ranking: stats.rankingXp,
          rankingOutOf: stats.rankingXpOutOf,
        ),
        const SizedBox(height: 20),
        Divider(color: AppTheme.borderOf(context)),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _HankinCard extends StatelessWidget {
  const _HankinCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.ranking,
    this.rankingOutOf,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final int? ranking;
  final int? rankingOutOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: FantasyTheme.cardBoxDecoration(context),
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
                        color: AppTheme.textPrimaryOf(context),
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
