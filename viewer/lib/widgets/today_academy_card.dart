import 'package:flutter/material.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Card lateral "Mural da academia" com conteúdo (ex.: filósofo, obra e citação).
class TodayAcademyCard extends StatelessWidget {
  const TodayAcademyCard({
    super.key,
    this.title = 'Mural da academia',
    this.philosopherName = 'Thomas Hobbes',
    this.years = '1588 - 1679',
    this.work = 'Obra: Leviatã (1651)',
    this.quote =
        'No estado de natureza, a vida seria "solitária, pobre, sórdida, '
        'odiosa e curta... Para escapar dessa situação e garantir a segurança '
        'pessoal, o indivíduo concordaria em formar um Estado, transferindo '
        'todos os seus direitos ao soberano (ou Leviatã), exceto o direito à vida.',
    this.buttonLabel = 'Toque para saber mais >',
    this.onTap,
  });

  final String title;
  final String philosopherName;
  final String years;
  final String work;
  final String quote;
  final String buttonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: FantasyTheme.cardGradient,
        borderRadius: FantasyTheme.cardBorderRadius,
        boxShadow: FantasyTheme.cardShadow,
        border: Border.all(
          color: FantasyTheme.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: FantasyTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: FantasyTheme.textMuted.withValues(alpha: 0.4),
            height: 1,
          ),
          const SizedBox(height: 12),
          Text(
            philosopherName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: FantasyTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            years,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FantasyTheme.textSecondary,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            work,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FantasyTheme.textSecondary,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: FantasyTheme.textMuted.withValues(alpha: 0.4),
            height: 1,
          ),
          const SizedBox(height: 12),
          Text(
            quote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FantasyTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
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
                  color: FantasyTheme.gold.withValues(alpha: 0.9),
                  borderRadius: FantasyTheme.buttonBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: FantasyTheme.goldDark.withValues(alpha: 0.3),
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
                      style:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: FantasyTheme.backgroundTop,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
