import 'package:flutter/material.dart';

import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/features/trophy_shelf/utils/shelf_layout_config.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/trophy_slot.dart';

/// Uma prateleira horizontal: container com posicionamento dos slots.
class ShelfRow extends StatelessWidget {
  final int rowIndex;
  final List<ShelfTrophy> trophiesInRow;
  final ShelfLayoutConfig config;
  final void Function(ShelfTrophy)? onTrophyTap;

  const ShelfRow({
    super.key,
    required this.rowIndex,
    required this.trophiesInRow,
    required this.config,
    this.onTrophyTap,
  });

  @override
  Widget build(BuildContext context) {
    final slotsPerRow = config.slotsPerRow;
    final slotSize = config.slotSize;
    final slots = List<Widget?>.filled(slotsPerRow, null);

    for (final st in trophiesInRow) {
      if (st.slotIndex >= 0 && st.slotIndex < slotsPerRow) {
        slots[st.slotIndex] = TrophySlot(
          shelfTrophy: st,
          size: slotSize,
          onTap: onTrophyTap != null ? () => onTrophyTap!(st) : null,
        );
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: config.horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(slotsPerRow, (i) {
          final slot = slots[i];
          return SizedBox(
            width: slotSize,
            height: slotSize,
            child: slot ?? TrophySlot(size: slotSize, shelfTrophy: null),
          );
        }),
      ),
    );
  }
}
