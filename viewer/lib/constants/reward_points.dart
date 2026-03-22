/// Limites de pontuação: vídeo diário e missões da semana (alinhado à API).
const int minRewardPoints = 10;
const int maxRewardPoints = 50;

bool isValidRewardPoints(int value) =>
    value >= minRewardPoints && value <= maxRewardPoints;

int clampRewardPoints(int value) {
  if (value < minRewardPoints) return minRewardPoints;
  if (value > maxRewardPoints) return maxRewardPoints;
  return value;
}
