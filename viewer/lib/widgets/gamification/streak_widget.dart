import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/widgets/gamification/login_bonus_ring.dart';

/// Exibe dias de sequência de login (valor vindo de `/auth/me`: `login_streak_days`).
///
/// Com [streakDays] null, não renderiza nada. [showPlaceholder] mostra "em breve" (legado).
///
/// Se [onOpenPointsRules] for definido, o anel **+PTS** (bónus de sequência) fica **dentro**
/// do mesmo cartão, à direita do texto.
class StreakWidget extends StatelessWidget {
  const StreakWidget({
    super.key,
    this.streakDays,
    this.showPlaceholder = false,
    this.onOpenPointsRules,
  });

  final int? streakDays;
  final bool showPlaceholder;

  /// Abre o sheet de regras de pontuação (ex. `showPointsRulesSheet` na home).
  final VoidCallback? onOpenPointsRules;

  static const double _ringSizeInCard = 62;

  @override
  Widget build(BuildContext context) {
    Widget? bonusTrailing(int streak) {
      final cb = onOpenPointsRules;
      if (cb == null) return null;
      return LoginBonusRing(
        streakDays: streak,
        onTap: cb,
        size: _ringSizeInCard,
      );
    }

    if (streakDays != null) {
      final n = streakDays!;
      if (n == 0) {
        return _StreakCard(
          icon: Icons.local_fire_department_outlined,
          title: '0',
          subtitle: 'Faça login todos os dias',
          emphasize: false,
          trailing: bonusTrailing(0),
        );
      }
      return _StreakCard(
        icon: Icons.local_fire_department_rounded,
        title: '$n',
        subtitle: n == 1 ? 'dia seguido' : 'dias seguidos',
        emphasize: true,
        trailing: bonusTrailing(n),
      );
    }
    if (!showPlaceholder) return const SizedBox.shrink();
    return _StreakCard(
      icon: Icons.local_fire_department_outlined,
      title: '—',
      subtitle: 'Sequência em breve',
      emphasize: false,
      trailing: bonusTrailing(0),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasize,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasize;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: emphasize ? primary : AppTheme.textMutedOf(context),
            size: 28,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryOf(context),
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
