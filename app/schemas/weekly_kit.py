"""Schemas para turmas semanais (1–5 técnicas; rótulo = nome da turma). Rotas HTTP mantêm o segmento `weekly-kits`."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.core.points_limits import MAX_REWARD_POINTS, MIN_REWARD_POINTS


class WeeklyKitItemInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    technique_id: UUID
    multiplier: int = Field(default=10, ge=MIN_REWARD_POINTS, le=MAX_REWARD_POINTS)


class WeeklyKitCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str = Field(..., min_length=1, max_length=255)
    sort_order: int = 0
    items: list[WeeklyKitItemInput] = Field(
        default_factory=list,
        description="Opcional na criação; use PATCH para definir 1–5 técnicas.",
    )


class WeeklyKitUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(None, min_length=1, max_length=255)
    sort_order: int | None = None
    items: list[WeeklyKitItemInput] | None = Field(
        None,
        description="Se enviado, substitui toda a lista (1–5 técnicas).",
    )


class WeeklyKitItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    order_index: int
    technique_id: UUID
    technique_name: str | None = None
    multiplier: int


class WeeklyKitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    academy_id: UUID
    label: str
    sort_order: int
    items: list[WeeklyKitItemRead] = Field(default_factory=list)


class WeeklyKitChoiceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kit_id: UUID = Field(description="Identificador da turma (registo `weekly_technique_kits`).")
    reference_date: str | None = Field(
        None,
        description="Data YYYY-MM-DD para calcular a semana ISO (default: hoje no fuso APP_TIMEZONE).",
    )


class WeeklyKitChoiceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kit_id: UUID
    iso_week_year: int
    iso_week_number: int
    academy_id: UUID
