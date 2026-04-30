import 'package:flutter/material.dart';

/// Cor do ícone/indicador por tier de medalha/troféu, alinhada ao [ColorScheme] Memo (primário verde).
Color trophyTierColor(BuildContext context, String? tier) {
  final cs = Theme.of(context).colorScheme;
  switch (tier) {
    case 'gold':
      return cs.primary;
    case 'silver':
      return cs.onSurfaceVariant;
    case 'bronze':
      return Color.lerp(cs.primary, cs.surface, 0.45)!;
    default:
      return cs.outline;
  }
}
