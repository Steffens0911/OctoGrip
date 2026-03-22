"""Cálculo de níveis ("reward_level") baseado no total de pontos do usuário.

Regra:
- Nível 1: threshold para avançar = 50 pontos.
- A cada nível: threshold(N) = ceil(threshold(N-1) * 1.2).
  (Implementado com aritmética inteira: ceil(x * 6/5) = (x*6 + 4)//5)
- Ao atingir threshold do nível atual, usuário sobe e o contador "level_points"
  recebe carry over (sobra continua valendo no próximo nível).
"""

from __future__ import annotations

from typing import Tuple


BASE_LEVEL_THRESHOLD: int = 50
GROWTH_NUM: int = 6
GROWTH_DEN: int = 5


def threshold_for_level(level: int) -> int:
    """Retorna quantos pontos são necessários para sair do `level` e ir para o `level+1`."""
    if level < 1:
        raise ValueError("level deve ser >= 1")

    threshold = BASE_LEVEL_THRESHOLD
    # level=1 -> BASE; level=2 -> ceil(BASE*1.2) etc.
    for _ in range(2, level + 1):
        threshold = (threshold * GROWTH_NUM + (GROWTH_DEN - 1)) // GROWTH_DEN
    return threshold


def compute_level_from_total_points(total_points: int) -> Tuple[int, int, int]:
    """Calcula (level, level_points, next_threshold) a partir do total acumulado.

    `level_points` é a pontuação acumulada dentro do nível atual (carry over),
    que deve ficar sempre em [0, next_threshold - 1] (exceto quando threshold muda).
    """
    if total_points < 0:
        total_points = 0

    level = 1
    remaining = total_points

    while True:
        next_threshold = threshold_for_level(level)
        if remaining >= next_threshold:
            remaining -= next_threshold
            level += 1
            continue
        return level, remaining, next_threshold

