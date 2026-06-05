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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Center(
                            child: ShelfRow(
                              rowIndex: rowIndex,
                              trophiesInRow: inRow,
                              config: config,
                              onTrophyTap: onTrophyTap,
                            ),
                          ),
                        ),
                        _ShelfPlank(horizontalPadding: config.horizontalPadding),
                        const _ShelfShadow(),
                      ],
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

class _ShelfPlank extends StatelessWidget {
  final double horizontalPadding;
  const _ShelfPlank({this.horizontalPadding = 24});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.3),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4924C),
              Color(0xFFA86228),
              Color(0xFF8B4E1E),
              Color(0xFF7A3E14),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color(0x1EFFFFFF),
              blurRadius: 0,
              offset: Offset(0, -1),
            ),
          ],
        ),
        // Wood grain overlay
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          child: CustomPaint(painter: _WoodGrainPainter()),
        ),
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter _) => false;
}

class _ShelfShadow extends StatelessWidget {
  const _ShelfShadow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Colors.transparent],
        ),
      ),
    );
  }
}
