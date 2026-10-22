"""Schemas da configuração do app por plataforma (versão mínima, flags)."""

from typing import Any

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.app_version import is_valid_app_version, parse_app_version


class AppConfigResponse(BaseModel):
    platform: str
    min_version: str = Field(description="Abaixo desta versão o app deve bloquear e pedir atualização.")
    latest_version: str = Field(description="Abaixo desta versão o app sugere atualizar, sem bloquear.")
    update_message: str | None = None
    store_url: str | None = None
    feature_flags: dict[str, Any] = Field(default_factory=dict)


class AppConfigUpdate(BaseModel):
    """Campos omitidos não mudam."""

    min_version: str | None = None
    latest_version: str | None = None
    update_message: str | None = None
    store_url: str | None = None
    feature_flags: dict[str, Any] | None = None

    @field_validator("min_version", "latest_version")
    @classmethod
    def _version_format(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not is_valid_app_version(value):
            raise ValueError("Use o formato MAIOR.MENOR.CORREÇÃO ou MAIOR.MENOR.CORREÇÃO+BUILD (ex.: 1.3.0+12).")
        return value

    @model_validator(mode="after")
    def _min_not_above_latest(self) -> "AppConfigUpdate":
        if self.min_version and self.latest_version:
            if parse_app_version(self.min_version) > parse_app_version(self.latest_version):
                raise ValueError("min_version não pode ser maior que latest_version.")
        return self


class AppVersionUsage(BaseModel):
    platform: str | None
    version: str
    users: int


class AppVersionDistributionResponse(BaseModel):
    days: int
    total_users: int
    versions: list[AppVersionUsage]
