import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophies/domain/entities/trophy_entity.dart';

class TrophyListCard extends StatelessWidget {
  const TrophyListCard({
    super.key,
    required this.entity,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final TrophyEntity entity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF2B2D42)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final sub = StringBuffer()
      ..write(entity.techniqueName ?? 'Técnica')
      ..write(' · ')
      ..write(entity.startDateIso)
      ..write(' a ')
      ..write(entity.endDateIso)
      ..write(' · Meta: ')
      ..write(entity.targetCount);
    if (entity.maxCountPerOpponent != null) {
      sub
        ..write(' · Máx. ')
        ..write(entity.maxCountPerOpponent)
        ..write('/adversário');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canEdit ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  color: AppTheme.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (canEdit) ...[
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
