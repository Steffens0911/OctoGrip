import 'package:flutter/material.dart';

import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/models/trophy.dart';

/// O troféu em si: ícone/imagem, estado bloqueado (opacidade), estado ouro (glow).
/// Animações: desbloqueio (scale/opacity) e pulsação suave para ouro.
class TrophyItem extends StatefulWidget {
  final ShelfTrophy shelfTrophy;
  final double size;

  const TrophyItem({
    super.key,
    required this.shelfTrophy,
    this.size = 64.0,
  });

  @override
  State<TrophyItem> createState() => _TrophyItemState();
}

class _TrophyItemState extends State<TrophyItem>
    with TickerProviderStateMixin {
  late AnimationController _unlockController;
  late AnimationController _pulseController;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _unlockController,
        curve: Curves.easeOutBack,
      ),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _unlockController, curve: Curves.easeOut),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.shelfTrophy.isUnlocked) {
      _unlockController.forward();
      if (widget.shelfTrophy.isGold) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _unlockController.value = 0;
      _opacity = const AlwaysStoppedAnimation(0.45);
      _scale = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void didUpdateWidget(TrophyItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shelfTrophy.isUnlocked && !oldWidget.shelfTrophy.isUnlocked) {
      _unlockController.forward();
    }
    if (widget.shelfTrophy.isGold && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.shelfTrophy.isGold && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _unlockController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  static Color _tierColor(String? tier) {
    switch (tier) {
      case 'gold':
        return const Color(0xFFD97706);
      case 'silver':
        return const Color(0xFF9CA3AF);
      case 'bronze':
        return const Color(0xFF92400E);
      default:
        return Colors.grey;
    }
  }

  static IconData _iconForTierAndKind(String? tier, bool isMedal) {
    if (isMedal) {
      return Icons.military_tech;
    }
    switch (tier) {
      case 'gold':
      case 'silver':
      case 'bronze':
        return Icons.emoji_events;
      default:
        return Icons.workspace_premium_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.shelfTrophy.data;
    final color = _tierColor(t.earnedTier);
    final icon = _iconForTierAndKind(t.earnedTier, t.isMedal);
    final isGold = widget.shelfTrophy.isGold;
    final isMedal = t.isMedal;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_unlockController, _pulseController]),
        builder: (context, child) {
          double scale = _scale.value;
          if (isGold && _unlockController.isCompleted) {
            scale *= _pulse.value;
          }
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: widget.size * 0.7,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                shape: isMedal ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isMedal ? null : BorderRadius.circular(10),
                boxShadow: isGold
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: widget.size * 0.45,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${t.awardKindLabel} · ${t.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!widget.shelfTrophy.isUnlocked) ...[
              const SizedBox(height: 2),
              if (t.minRewardLevelToUnlock > 0)
                Text(
                  'Nível ${t.minRewardLevelToUnlock} para desbloquear',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              if (t.minGraduationToUnlock != null && t.minGraduationToUnlock!.isNotEmpty)
                Text(
                  'Faixa mín.: ${TrophyWithEarned.graduationLabel(t.minGraduationToUnlock) ?? t.minGraduationToUnlock}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
