import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/models/trophy.dart';

/// Modal/bottom sheet ao tocar no troféu: nome, técnica, tier, datas, progresso.
class TrophyDetailModal extends StatelessWidget {
  final ShelfTrophy shelfTrophy;
  final String? galleryOwnerName;

  const TrophyDetailModal({
    super.key,
    required this.shelfTrophy,
    this.galleryOwnerName,
  });

  static Future<void> show(
    BuildContext context,
    ShelfTrophy shelfTrophy, {
    String? galleryOwnerName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrophyDetailModal(
        shelfTrophy: shelfTrophy,
        galleryOwnerName: galleryOwnerName,
      ),
    );
  }

  static String _formatDateRange(String startIso, String endIso) {
    try {
      final start = DateTime.tryParse(startIso);
      final end = DateTime.tryParse(endIso);
      if (start == null || end == null) return '$startIso – $endIso';
      return '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} – '
          '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
    } catch (_) {
      return '$startIso – $endIso';
    }
  }

  static Color _tierColor(BuildContext context, String? tier) {
    switch (tier) {
      case 'gold':
        return const Color(0xFFD97706);
      case 'silver':
        return const Color(0xFF9CA3AF);
      case 'bronze':
        return const Color(0xFF92400E);
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = shelfTrophy.data;
    final theme = Theme.of(context);

    return Semantics(
      label: 'Detalhes do troféu ${t.name}. ${t.tierLabel}. Arraste para baixo ou toque em Fechar para sair.',
      child: Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _tierColor(context, t.earnedTier).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  t.earnedTier != null ? Icons.emoji_events : Icons.workspace_premium_outlined,
                  color: _tierColor(context, t.earnedTier),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (t.techniqueName != null && t.techniqueName!.isNotEmpty)
                      Text(
                        t.techniqueName!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      t.tierLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _tierColor(context, t.earnedTier),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_formatDateRange(t.startDate, t.endDate)} · Meta: ${t.targetCount} execuções',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMutedOf(context),
            ),
          ),
          if (_hasProgress(t)) ...[
            const SizedBox(height: 12),
            _progressSection(context, t),
          ],
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Fechar detalhes do troféu',
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
      ),
    );
  }

  bool _hasProgress(TrophyWithEarned t) {
    return t.earnedTier != null || t.goldCount > 0 || t.silverCount > 0 || t.bronzeCount > 0;
  }

  Widget _progressSection(BuildContext context, TrophyWithEarned t) {
    final style = TextStyle(
      fontSize: 12,
      color: AppTheme.textSecondaryOf(context),
    );
    final lines = <Widget>[];
    final hasGold = t.earnedTier == 'gold';
    final hasSilver = t.earnedTier == 'silver' || hasGold;
    final hasBronze = t.earnedTier == 'bronze' || hasSilver;
    if (hasGold) {
      final goldText = galleryOwnerName == null
          ? 'Você conquistou ouro neste troféu.'
          : galleryOwnerName!.isEmpty
              ? 'Conquistou ouro neste troféu.'
              : '$galleryOwnerName conquistou ouro neste troféu.';
      lines.add(Text(
        goldText,
        style: style.copyWith(
          fontWeight: FontWeight.w600,
          color: _tierColor(context, 'gold'),
        ),
      ));
    } else {
      if (!hasBronze && t.targetCount - t.bronzeCount > 0) {
        lines.add(Text(
          '${t.bronzeCount} de ${t.targetCount} para bronze.',
          style: style,
        ));
      }
      if (!hasSilver && t.targetCount - t.silverCount > 0) {
        lines.add(Text(
          '${t.silverCount} de ${t.targetCount} para prata.',
          style: style,
        ));
      }
      if (!hasGold && t.targetCount - t.goldCount > 0) {
        lines.add(Text(
          '${t.goldCount} de ${t.targetCount} para ouro.',
          style: style,
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: w,
              ))
          .toList(),
    );
  }
}
