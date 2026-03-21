import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/techniques/domain/entities/technique_entity.dart';

/// Card de linha com nome + editar + excluir (layout próximo ao mock M3).
class TechniqueListCard extends StatelessWidget {
  const TechniqueListCard({
    super.key,
    required this.entity,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final TechniqueEntity entity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF2B2D42)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

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
                    if (entity.isOptimistic)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Salvando…',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.primary,
                              ),
                        ),
                      ),
                    if (entity.description != null &&
                        entity.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          entity.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                              ),
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
