import 'package:flutter/material.dart';

import 'package:viewer/features/trophy_shelf/domain/shelf_trophy.dart';
import 'package:viewer/features/trophy_shelf/utils/shelf_layout_config.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/shelf_background.dart';
import 'package:viewer/features/trophy_shelf/presentation/widgets/shelf_row.dart';

/// Compõe ShelfBackground + N ShelfRow com TrophySlot/TrophyItem a partir da lista de ShelfTrophy.
class TrophyShelfLayout extends StatelessWidget {
  final List<ShelfTrophy> shelfTrophies;
  final ShelfLayoutConfig config;
  final void Function(ShelfTrophy)? onTrophyTap;

  const TrophyShelfLayout({
    super.key,
    required this.shelfTrophies,
    required this.config,
    this.onTrophyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: ShelfBackground()),
        LayoutBuilder(
          builder: (context, constraints) {
            final rowCount = config.rowCount;
            final rowHeight = (constraints.maxHeight - config.topOffsetFraction * constraints.maxHeight) / rowCount;
            final topOffset = constraints.maxHeight * config.topOffsetFraction;

            return Padding(
              padding: EdgeInsets.only(top: topOffset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(rowCount, (rowIndex) {
                  final inRow = shelfTrophies
                      .where((s) => s.shelfRowIndex == rowIndex)
                      .toList();
                  return SizedBox(
                    height: rowHeight - config.rowSpacing,
                    child: Center(
                      child: ShelfRow(
                        rowIndex: rowIndex,
                        trophiesInRow: inRow,
                        config: config,
                        onTrophyTap: onTrophyTap,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}
