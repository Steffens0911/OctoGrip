import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';

/// Cartão compacto tipo grelha Central (ícone 36, título, subtítulo); variante destacada opcional.
class MemoCompactTileCard extends StatelessWidget {
  const MemoCompactTileCard({
    super.key,
    required this.featured,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool featured;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final surface = featured
        ? scheme.primary.withValues(alpha: 0.14)
        : AppTheme.surfaceOf(context);

    final borderColor = featured
        ? scheme.primary.withValues(alpha: 0.42)
        : AppTheme.borderOf(context);

    final iconBg = featured
        ? scheme.primary.withValues(alpha: 0.26)
        : scheme.primary.withValues(alpha: 0.1);

    final titleStyleBase =
        Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyleBase = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          height: 1.25,
        );

    final titleColor =
        featured ? scheme.primary : AppTheme.textPrimaryOf(context);
    final subtitleColor = featured
        ? scheme.primary.withValues(alpha: 0.72)
        : AppTheme.textMutedOf(context);

    final inner = Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: borderColor, width: featured ? 1 : 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: AppRadius.tileRadius,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              AppSpacing.verticalS,
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyleBase?.copyWith(color: titleColor, fontSize: 13.5),
              ),
              AppSpacing.verticalXs,
              Text(
                subtitle,
                maxLines: featured ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyleBase?.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
      ),
    );

    final decorated = featured
        ? inner
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              boxShadow: AppShadow.card(context),
            ),
            child: inner,
          );

    if (enabled) return decorated;
    return Opacity(
      opacity: 0.45,
      child: IgnorePointer(child: decorated),
    );
  }
}
