import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';

/// Exibe dias de sequência de treino quando a API expuser o valor.
///
/// Com [streakDays] null, não renderiza nada (evita dados inventados).
/// Com [showPlaceholder], mostra um cartão discreto "Sequência · em breve".
class StreakWidget extends StatelessWidget {
  const StreakWidget({
    super.key,
    this.streakDays,
    this.showPlaceholder = false,
  });

  final int? streakDays;
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (streakDays != null) {
      final n = streakDays!;
      return _StreakCard(
        icon: Icons.local_fire_department_rounded,
        title: '$n',
        subtitle: n == 1 ? 'dia seguido' : 'dias seguidos',
        emphasize: true,
      );
    }
    if (!showPlaceholder) return const SizedBox.shrink();
    return const _StreakCard(
      icon: Icons.local_fire_department_outlined,
      title: '—',
      subtitle: 'Sequência em breve',
      emphasize: false,
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasize,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderOf(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );
  }
}
