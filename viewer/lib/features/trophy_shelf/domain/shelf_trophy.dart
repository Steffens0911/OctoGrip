import 'package:viewer/models/trophy.dart';

/// Entidade de apresentação: troféu posicionado na estante (slot + estado de UI).
class ShelfTrophy {
  final TrophyWithEarned data;
  final int shelfRowIndex;
  final int slotIndex;
  final bool isUnlocked;
  final bool isGold;

  ShelfTrophy({
    required this.data,
    required this.shelfRowIndex,
    required this.slotIndex,
    bool? isUnlocked,
    bool? isGold,
  })  : isUnlocked = isUnlocked ?? (data.earnedTier != null),
        isGold = isGold ?? (data.earnedTier == 'gold');

  /// Mapeia lista da API para lista de estante com posições determinísticas.
  /// Ordenação: end_date desc, depois name, para ordem estável.
  static List<ShelfTrophy> fromTrophies(
    List<TrophyWithEarned> trophies, {
    required int slotsPerRow,
    required int rowCount,
  }) {
    final sorted = List<TrophyWithEarned>.from(trophies)
      ..sort((a, b) {
        final endCmp = (b.endDate).compareTo(a.endDate);
        if (endCmp != 0) return endCmp;
        return (a.name).compareTo(b.name);
      });
    final result = <ShelfTrophy>[];
    var slot = 0;
    final maxSlots = slotsPerRow * rowCount;
    for (var i = 0; i < sorted.length && slot < maxSlots; i++) {
      final row = slot ~/ slotsPerRow;
      final col = slot % slotsPerRow;
      result.add(ShelfTrophy(
        data: sorted[i],
        shelfRowIndex: row,
        slotIndex: col,
      ));
      slot++;
    }
    return result;
  }
}
