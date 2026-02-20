"""Dependências FastAPI para autenticação JWT."""
import logging
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AuthenticationError, ForbiddenError
from app.core.middleware import set_request_context
from app.core.security import decode_access_token
from app.database import get_db
from app.models import User
from app.services.user_service import get_user

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User:
    """Exige Bearer JWT válido e retorna o User. Se admin enviar X-Impersonate-User, retorna esse usuário."""
    if not credentials or credentials.scheme.lower() != "bearer":
        raise AuthenticationError("Token de autenticação ausente ou inválido.")
    user_id_str = decode_access_token(credentials.credentials)
    if not user_id_str:
        raise AuthenticationError("Token inválido ou expirado.")
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise AuthenticationError("Token inválido.")
    real_user = await get_user(db, user_id)
    if not real_user:
        raise AuthenticationError("Usuário não encontrado.")

    set_request_context(
        user_id=str(real_user.id),
        academy_id=str(real_user.academy_id) if real_user.academy_id else None,
    )

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


async def get_current_user_optional(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User | None:
    """Se houver Bearer JWT válido, retorna o User; senão retorna None."""
    if not credentials or credentials.scheme.lower() != "bearer":
        return None
    user_id_str = decode_access_token(credentials.credentials)
    if not user_id_str:
        return None
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        return None
    return await get_user(db, user_id)
