import 'package:flutter/material.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Card "Horários da academia" com ícone de relógio e botão "Ver agenda".
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    this.title = 'Horários da academia',
    this.description =
        'Consulte os horários disponíveis da academia.',
    this.buttonLabel = 'Ver agenda',
    this.onTap,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = FantasyTheme.accentOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: FantasyTheme.cardBoxDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: FantasyTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FantasyTheme.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: FantasyTheme.buttonBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: FantasyTheme.accentStrongOf(context),
                        borderRadius: FantasyTheme.buttonBorderRadius,
                        boxShadow: [
                          BoxShadow(
                            color:
                                FantasyTheme.accentShadowOf(context),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            buttonLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color:
                                      FantasyTheme.onAccentForegroundOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color:
                                FantasyTheme.onAccentForegroundOf(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
