/// Cálculo de níveis alinhado a [app/core/leveling.py] (reward_level).
///
/// Nível 1: 50 pontos para avançar; depois threshold(N) = ceil(threshold(N-1) * 1.2)
/// via inteiro (x*6+4)//5.
library;

const int kBaseLevelThreshold = 50;

const int _growthNum = 6;
const int _growthDen = 5;

/// Progresso no nível atual para exibir na barra XP.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.levelPoints,
    required this.nextThreshold,
  });

  final int level;
  final int levelPoints;
  final int nextThreshold;
}

int thresholdForLevel(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'deve ser >= 1');
  }
  var threshold = kBaseLevelThreshold;
  for (var l = 2; l <= level; l++) {
    threshold = (threshold * _growthNum + (_growthDen - 1)) ~/ _growthDen;
  }
  return threshold;
}

LevelProgress computeLevelFromTotalPoints(int totalPoints) {
  var total = totalPoints < 0 ? 0 : totalPoints;
  var level = 1;
  var remaining = total;

  while (true) {
    final nextThreshold = thresholdForLevel(level);
    if (remaining >= nextThreshold) {
      remaining -= nextThreshold;
      level += 1;
      continue;
    }
    return LevelProgress(
      level: level,
      levelPoints: remaining,
      nextThreshold: nextThreshold,
    );
  }
}

/// Lê int a partir de JSON (int ou double).
int? readIntFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// Usa o total `points` da API como fonte da verdade (mesmo que level_* venham ausentes ou defasados).
LevelProgress levelProgressFromUserPointsMap(Map<String, dynamic> map) {
  final total = readIntFromJson(map['points']) ?? 0;
  return computeLevelFromTotalPoints(total);
}
