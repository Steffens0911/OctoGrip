"""Schemas para User (CRUD desenvolvedores)."""
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class UserRead(BaseModel):
    id: UUID
    email: str
    name: str | None
    graduation: str | None = None
    role: str = "aluno"
    academy_id: UUID | None = None
    points_adjustment: int = 0

    class Config:
        from_attributes = True


VALID_GRADUATIONS = frozenset({"white", "blue", "purple", "brown", "black"})
VALID_ROLES = frozenset({"aluno", "professor", "gerente_academia", "administrador", "supervisor"})


def _validate_graduation(v: str | None) -> str:
    if not v or not v.strip():
        raise ValueError("graduation é obrigatório")
    g = v.strip().lower()
    if g not in VALID_GRADUATIONS:
        raise ValueError(
            f"graduation deve ser um de: {', '.join(sorted(VALID_GRADUATIONS))}"
        )
    return g


def _validate_role(v: str | None) -> str:
    if not v or not v.strip():
        return "aluno"  # padrão
    r = v.strip().lower()
    if r not in VALID_ROLES:
        raise ValueError(
            f"role deve ser um de: {', '.join(sorted(VALID_ROLES))}"
        )
    return r


def _validate_password_strength(password: str) -> str:
    """Valida força da senha: mínimo 12 caracteres."""
    if len(password) < 12:
        raise ValueError("Senha deve ter pelo menos 12 caracteres.")
    if len(password) > 128:
        raise ValueError("Senha não pode ter mais de 128 caracteres.")
    return password


class UserCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(..., description="E-mail do usuário (deve ser válido)")
    password: str | None = Field(
        None,
        min_length=12,
        max_length=128,
        description="Senha para login (opcional, mínimo 12 caracteres). Se não informada, usuário não poderá fazer login.",
    )
    name: str | None = Field(None, max_length=255)
    graduation: str | None = Field(None, min_length=1, max_length=32)
    role: str = Field(default="aluno", max_length=32)
    academy_id: UUID | None = None

    @field_validator("graduation")
    @classmethod
    def graduation_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_graduation(v)

    @field_validator("role")
    @classmethod
    def role_valid(cls, v: str) -> str:
        return _validate_role(v)

    @field_validator("password")
    @classmethod
    def password_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_password_strength(v)

    @model_validator(mode="after")
    def validate_role_graduation(self):
        """Valida que professor e aluno exigem graduation."""
        if self.role in ("professor", "aluno"):
            if not self.graduation or not self.graduation.strip():
                raise ValueError(f"role '{self.role}' exige graduation")
        return self


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, max_length=255)
    graduation: str | None = Field(None, max_length=32)
    role: str | None = Field(None, max_length=32)
    academy_id: UUID | None = None
    points_adjustment: int | None = None
    password: str | None = Field(
        None,
        min_length=12,
        max_length=128,
        description="Nova senha para login (mínimo 12 caracteres). Se informada, substitui a senha atual. Deixe em branco para não alterar.",
    )

    @field_validator("password")
    @classmethod
    def password_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        if not v.strip():
            return None
        return _validate_password_strength(v)

    @field_validator("graduation")
    @classmethod
    def graduation_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_graduation(v)

    @field_validator("role")
    @classmethod
    def role_valid(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _validate_role(v)

    @model_validator(mode="after")
    def validate_role_graduation(self):
        """Valida que professor e aluno exigem graduation."""
        # Se role está sendo atualizado, verificar graduation
        if self.role is not None:
            if self.role in ("professor", "aluno"):
                # Se graduation não está sendo atualizado, precisamos verificar o valor atual no banco
                # Por enquanto, validamos apenas se graduation foi informado
                if self.graduation is None or not self.graduation.strip():
                    # Se role está sendo mudado para professor/aluno sem graduation, erro
                    raise ValueError(f"role '{self.role}' exige graduation")
        # Se role não está sendo atualizado mas graduation está, não há problema
        return self
