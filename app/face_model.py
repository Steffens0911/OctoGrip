from __future__ import annotations

from typing import Any

_model: Any | None = None


def get_model() -> Any:
    """
    Carrega e mantém o modelo de face em memória por processo.

    Observação: em produção com múltiplos workers/processos (Uvicorn/Celery),
    cada processo terá o seu próprio cache em memória (comportamento esperado).
    """

    global _model
    if _model is None:
        from deepface import DeepFace

        _model = DeepFace.build_model("Facenet512")
    return _model

