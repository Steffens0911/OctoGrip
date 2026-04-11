import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/theme/fantasy_theme.dart';

/// Placeholders discretos enquanto header e missões ainda não chegam da API.
class HomeHeaderLoadingSkeleton extends StatelessWidget {
  const HomeHeaderLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FantasyTheme.textMutedOf(context).withValues(alpha: 0.22);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(context, 0.45, 26, c),
          const SizedBox(height: 12),
          _line(context, 0.92, 14, c),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(context, 1, 12, c),
                    const SizedBox(height: 10),
                    _line(context, 0.55, 12, c),
                    const SizedBox(height: 16),
                    _line(context, 1, 10, c),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _line(context, 1, 8, c),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    double widthFactor,
    double height,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth * widthFactor;
        return Container(
          height: height,
          width: w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

/// Cartão placeholder para o bloco "Missões da semana".
class HomeMissionSectionSkeleton extends StatelessWidget {
  const HomeMissionSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FantasyTheme.textMutedOf(context).withValues(alpha: 0.22);
    final border = AppTheme.borderOf(context);
    final surface = AppTheme.surfaceOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lineTitle(context, 180, 16, c),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 2 ? 0 : 6),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lineTitle(
    BuildContext context,
    double width,
    double height,
    Color color,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
