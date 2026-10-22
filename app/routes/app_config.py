"""Configuração do app cliente: versão mínima, versão mais recente e feature flags.

- ``GET /app/config`` é público: o app consulta ao abrir, antes do login.
- ``/admin/app-config`` e ``/admin/app-versions`` são do administrador da plataforma.
"""

from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppError
from app.core.role_deps import require_admin
from app.database import get_db
from app.models import User
from app.schemas.app_config import AppConfigResponse, AppConfigUpdate, AppVersionDistributionResponse
from app.services.app_config_service import (
    app_version_distribution,
    get_app_config,
    list_app_configs,
    upsert_app_config,
)

Platform = Literal["android", "ios", "web"]

router = APIRouter()
admin_router = APIRouter()


@router.get("/config", response_model=AppConfigResponse)
async def read_app_config(
    platform: Platform = Query(..., description="Plataforma do app: android, ios ou web."),
    db: AsyncSession = Depends(get_db),
):
    """Versão mínima/mais recente e feature flags da plataforma. Sem configuração cadastrada, nada bloqueia."""
    return await get_app_config(db, platform)


@admin_router.get("/app-config", response_model=list[AppConfigResponse])
async def admin_list_app_configs(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),  # autorização apenas
):
    return await list_app_configs(db)


@admin_router.put("/app-config/{platform}", response_model=AppConfigResponse)
async def admin_update_app_config(
    platform: Platform,
    body: AppConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),  # autorização apenas
):
    """Atualiza a config da plataforma. Subir ``min_version`` obriga quem está abaixo a atualizar (426)."""
    values = body.model_dump(exclude_unset=True)
    current = await get_app_config(db, platform)
    merged = current | values
    if body.min_version or body.latest_version:
        # Valida o par final (um dos dois pode ter vindo do banco).
        try:
            AppConfigUpdate(min_version=merged["min_version"], latest_version=merged["latest_version"])
        except ValueError as exc:
            raise AppError("min_version não pode ser maior que latest_version.", status_code=422) from exc
    return await upsert_app_config(db, platform, values)


@admin_router.get("/app-versions", response_model=AppVersionDistributionResponse)
async def admin_app_versions(
    days: int = Query(30, ge=1, le=365, description="Considera usuários vistos nos últimos N dias."),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),  # autorização apenas
):
    """Quantos usuários ativos estão em cada versão do app: libera o passo de subir a versão mínima."""
    versions = await app_version_distribution(db, days)
    return {"days": days, "total_users": sum(v["users"] for v in versions), "versions": versions}
