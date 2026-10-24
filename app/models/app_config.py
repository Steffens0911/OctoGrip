"""Configuração do app por plataforma: versão mínima/mais recente e feature flags.

Uma linha por plataforma (android, ios, web). Lida por GET /app/config ao abrir o app e
pela checagem de versão mínima (resposta 426) em todas as rotas.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

APP_PLATFORMS = ("android", "ios", "web")


class AppConfig(Base):
    __tablename__ = "app_config"

    platform: Mapped[str] = mapped_column(String(16), primary_key=True, comment="android | ios | web")
    # server_default (e não só default): o bootstrap roda create_all ANTES das migrations, então a
    # tabela nasce do modelo. Sem padrão no banco, o INSERT da migration 091 violava o NOT NULL.
    min_version: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="0.0.0",
        server_default="0.0.0",
        comment="Abaixo desta versão o app é obrigado a atualizar (API responde 426).",
    )
    latest_version: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default="0.0.0",
        server_default="0.0.0",
        comment="Versão mais recente publicada; abaixo dela o app sugere atualizar.",
    )
    update_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    store_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    feature_flags: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
        comment='Ex.: {"novo_ranking": {"enabled": true, "min_app_version": "1.4.0"}}',
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
