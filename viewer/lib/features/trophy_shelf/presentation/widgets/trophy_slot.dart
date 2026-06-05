import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/trophy_item.dart';

/// Um lugar na prateleira (vazio ou ocupado). Área clicável; feedback de toque (scale 0.98).
class TrophySlot extends StatefulWidget {
  final ShelfTrophy? shelfTrophy;
  final double size;
  final VoidCallback? onTap;

  const TrophySlot({
    super.key,
    this.shelfTrophy,
    required this.size,
    this.onTap,
  });

  @override
  State<TrophySlot> createState() => _TrophySlotState();
}

class _TrophySlotState extends State<TrophySlot> {
  bool _pressed = false;

  String get _semanticLabel {
    if (widget.shelfTrophy == null) return 'Slot vazio';
    final t = widget.shelfTrophy!.data;
    final tier = t.earnedTier == null
        ? 'bloqueado'
        : t.earnedTier == 'gold'
            ? 'ouro'
            : t.earnedTier == 'silver'
                ? 'prata'
                : 'bronze';
    return '${t.name}, $tier. Toque para ver detalhes';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final minSize = size.clamp(48.0, double.infinity);
    return Semantics(
      button: widget.shelfTrophy != null,
      enabled: widget.shelfTrophy != null,
      label: _semanticLabel,
      child: SizedBox(
        width: minSize,
        height: minSize,
        child: GestureDetector(
          onTapDown: widget.shelfTrophy != null ? (_) => setState(() => _pressed = true) : null,
          onTapUp: widget.shelfTrophy != null ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: widget.shelfTrophy != null ? () => setState(() => _pressed = false) : null,
          onTap: widget.shelfTrophy != null
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onTap?.call();
                  setState(() => _pressed = false);
                }
              : null,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.shelfTrophy != null
                      ? TrophyItem(
                          shelfTrophy: widget.shelfTrophy!,
                          size: size * 0.85,
                        )
                      : _emptySlot(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptySlot() {
    final slotInner = widget.size * 0.85;
    return Container(
      width: slotInner,
      height: slotInner,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E0604), Color(0xFF1A0C08)],
        ),
        border: Border.all(color: Colors.black38, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.emoji_events,
        size: slotInner * 0.45,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }
}
