"""Paginação padronizada para listagens expostas pela API HTTP.

Limite máximo por página: 50 (plano de performance: menos carga em memória, respostas
previsíveis). Serviços que aplicam *clamp* interno devem importar ``MAX_LIST_LIMIT``.

Documentação relacionada: ``docs/DB_PERFORMANCE_HOTPATHS.md``.
"""

from __future__ import annotations

# Limite máximo de itens por requisição em endpoints de listagem (query param `limit`).
MAX_LIST_LIMIT: int = 50


def clamp_list_limit(value: int, *, maximum: int | None = None) -> int:
    """Garante 1 <= resultado <= maximum (default: MAX_LIST_LIMIT)."""
    cap = MAX_LIST_LIMIT if maximum is None else maximum
    return min(max(1, int(value)), cap)
