"""Dependências FastAPI para autenticação JWT."""
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.services.user_service import get_user
from app.core.security import decode_access_token

security = HTTPBearer(auto_error=False)


def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User:
    """Exige Bearer JWT válido e retorna o User. Se admin enviar X-Impersonate-User, retorna esse usuário."""
    if not credentials or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticação ausente ou inválido.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id_str = decode_access_token(credentials.credentials)
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido ou expirado.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    real_user = get_user(db, user_id)
    if not real_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuário não encontrado.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    impersonate_header = request.headers.get("X-Impersonate-User")
    if impersonate_header and real_user.role == "administrador":
        try:
            target_id = UUID(impersonate_header.strip())
            target_user = get_user(db, target_id)
            if target_user:
                return target_user
        except ValueError:
            pass
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário para simulação não encontrado.",
        )
    return real_user


def get_current_user_optional(
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> User | None:
    """Se houver Bearer JWT válido, retorna o User; senão retorna None (não levanta 401)."""
    if not credentials or credentials.scheme.lower() != "bearer":
        return None
    user_id_str = decode_access_token(credentials.credentials)
    if not user_id_str:
        return None
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        return None
    return get_user(db, user_id)
