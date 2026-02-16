"""Pontos por graduação (faixa) para gamificação.

Regra: pontuação = (pontuação base da técnica/slot da semana) × (valor da faixa de quem SOFREU a técnica).
Ex.: armlock base 1, aplicado em oponente faixa preta (5) → 1 × 5 = 5 pontos. A faixa de quem aplicou não entra no cálculo.
Valores da faixa: branca=1, azul=2, roxa=3, marrom=4, preta=5.
"""
from typing import Literal

GraduationValue = Literal["white", "blue", "purple", "brown", "black"]

GRADUATION_POINTS: dict[str, int] = {
    "white": 1,
    "blue": 2,
    "purple": 3,
    "brown": 4,
    "black": 5,
}

def points_for_graduation(graduation: str | None) -> int:
    """Retorna os pontos base da faixa (1-5). Se inválida ou None, retorna 0."""
    if not graduation or not graduation.strip():
        return 0
    return GRADUATION_POINTS.get(graduation.strip().lower(), 0)


def calculate_points_awarded(
    opponent_graduation: str | None,
    outcome: str,
    base_points: int | None = None,
) -> int:
    """
    Calcula pontos concedidos ao executor.
    opponent_graduation = faixa de quem SOFREU a técnica (quem confirma).
    Se base_points informado: pontos = base_points × valor_faixa_oponente (1-5).
    Senão (legado): pontos = valor da faixa do oponente.
    Sem bônus por outcome.
    """
    multiplier = points_for_graduation(opponent_graduation)
    if base_points is not None and base_points > 0:
        return base_points * multiplier
    return multiplier
