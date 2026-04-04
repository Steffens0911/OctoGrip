import 'package:flutter/material.dart';

import 'package:viewer/theme/fantasy_theme.dart';

/// Secção **Troféus** alinhada à home fantasia: título + cartão com gradiente
/// e linhas tocáveis (estilo [PartnersCard]).
class TrophiesHomeSection extends StatelessWidget {
  const TrophiesHomeSection({
    super.key,
    required this.onOpenGallery,
    this.onOpenClassmates,
    this.showClassmatesRow = false,
  });

  final VoidCallback onOpenGallery;
  final VoidCallback? onOpenClassmates;
  final bool showClassmatesRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Troféus',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: FantasyTheme.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: FantasyTheme.cardBoxDecoration(context),
          child: ClipRRect(
            borderRadius: FantasyTheme.cardBorderRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TrophyRow(
                  icon: Icons.emoji_events_outlined,
                  title: 'Galeria de troféus',
                  subtitle: 'Conquistas ouro, prata e bronze',
                  onTap: onOpenGallery,
                ),
                if (showClassmatesRow && onOpenClassmates != null) ...[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: FantasyTheme.textMutedOf(context)
                        .withValues(alpha: 0.2),
                  ),
                  _TrophyRow(
                    icon: Icons.people_outline,
                    title: 'Galeria dos colegas',
                    subtitle: 'Troféus e medalhas da academia',
                    onTap: onOpenClassmates!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrophyRow extends StatelessWidget {
  const _TrophyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FantasyTheme.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FantasyTheme.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: FantasyTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FantasyTheme.textSecondaryOf(context),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: FantasyTheme.textMutedOf(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
