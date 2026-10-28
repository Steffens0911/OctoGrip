"""Dependências FastAPI para autenticação JWT."""

import logging
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.app_version import APP_PLATFORM_HEADER, APP_VERSION_HEADER, is_valid_app_version, normalize_platform
from app.core.exceptions import AccountFrozenError, AuthenticationError, ForbiddenError
from app.core.middleware import set_request_context
from app.core.security import decode_access_token, token_matches_password
from app.database import get_db
from app.models import User
from app.services.app_config_service import record_app_version
from app.services.user_service import get_user

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)


async def user_from_token(db: AsyncSession, token: str) -> User | None:
    """Usuário dono do JWT, ou None se o token for inválido, vencido ou anterior à troca de senha."""
    payload = decode_access_token(token)
    if payload is None:
        return None
    try:
        user_id = UUID(str(payload["sub"]))
    except ValueError:
        return None
    user = await get_user(db, user_id)
    if user is None or not token_matches_password(payload, user.password_hash):
        return None
    return user


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User:
    """Exige Bearer JWT válido e retorna o User. Se admin enviar X-Impersonate-User, retorna esse usuário."""
    if not credentials or credentials.scheme.lower() != "bearer":
        raise AuthenticationError("Token de autenticação ausente ou inválido.")
    real_user = await user_from_token(db, credentials.credentials)
    if not real_user:
        raise AuthenticationError("Token inválido ou expirado.")

    set_request_context(
        user_id=str(real_user.id),
        academy_id=str(real_user.academy_id) if real_user.academy_id else None,
    )

    # Versão do app do usuário real (não do simulado): base do ciclo de depreciação da API.
    app_version = request.headers.get(APP_VERSION_HEADER)
    if app_version and is_valid_app_version(app_version):
        platform = normalize_platform(request.headers.get(APP_PLATFORM_HEADER))
        await record_app_version(db, real_user, app_version.strip(), platform)

    impersonate_header = request.headers.get("X-Impersonate-User")
    if impersonate_header and real_user.role == "administrador":
        try:
            target_id = UUID(impersonate_header.strip())
            target_user = await get_user(db, target_id)
            if target_user:
                set_request_context(
                    user_id=str(target_user.id),
                    academy_id=str(target_user.academy_id) if target_user.academy_id else None,
                )
                logger.warning(
                    "Admin impersonation: admin_id=%s impersonating user_id=%s",
                    real_user.id,
                    target_user.id,
                    extra={
                        "event_type": "admin_impersonation",
                        "admin_id": str(real_user.id),
                        "target_user_id": str(target_user.id),
                    },
                )
                return target_user
        except ValueError:
            pass
        logger.warning(
            "Admin impersonation failed: admin_id=%s target=%s",
            real_user.id,
            impersonate_header,
            extra={
                "event_type": "admin_impersonation_failed",
                "admin_id": str(real_user.id),
                "target_user_id": impersonate_header,
            },
        )
        raise ForbiddenError("Usuário para simulação não encontrado.")
    return real_user


async def get_real_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User:
    """Retorna sempre o usuário real do JWT, ignorando X-Impersonate-User.
    Útil para checar o papel do admin em rotas onde a impersonation não deve
    rebaixar permissões (ex.: atualizar configurações admin de academia)."""
    if not credentials or credentials.scheme.lower() != "bearer":
        raise AuthenticationError("Token de autenticação ausente ou inválido.")
    real_user = await user_from_token(db, credentials.credentials)
    if not real_user:
        raise AuthenticationError("Token inválido ou expirado.")
    return real_user


async def require_aluno_not_frozen(
    current_user: User = Depends(get_current_user),
) -> User:
    """Bloqueia alunos com account_frozen (operações mutáveis). Staff e supervisão não são afetados pelo flag."""
    if current_user.role == "aluno" and getattr(current_user, "account_frozen", False):
        raise AccountFrozenError()
    return current_user


async def get_current_user_optional(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User | None:
    """Se houver Bearer JWT válido, retorna o User; senão retorna None."""
    if not credentials or credentials.scheme.lower() != "bearer":
        return None
    return await user_from_token(db, credentials.credentials)
