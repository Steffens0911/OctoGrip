"""Dependências FastAPI para autorização baseada em roles."""
import logging

from fastapi import Depends

from app.core.auth_deps import get_current_user
from app.core.exceptions import ForbiddenError
from app.core.metrics import security_events_total
from app.models import User

logger = logging.getLogger(__name__)


def _log_access_denied(user: User, required: str) -> None:
    security_events_total.labels(event_type="access_denied").inc()
    logger.warning(
        "Acesso negado",
        extra={
            "user_id": str(user.id),
            "user_role": user.role,
            "required_access": required,
            "academy_id": str(user.academy_id) if user.academy_id else None,
        },
    )


def require_role(allowed_roles: list[str]):
    """Factory que retorna dependência exigindo um dos roles permitidos."""
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            _log_access_denied(current_user, f"role in {allowed_roles}")
            raise ForbiddenError(f"Acesso negado. Roles permitidos: {', '.join(allowed_roles)}")
        return current_user
    return role_checker


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Exige que o usuário seja administrador."""
    if current_user.role != "administrador":
        _log_access_denied(current_user, "administrador")
        raise ForbiddenError("Acesso negado. Apenas administradores podem acessar este recurso.")
    return current_user


def require_admin_or_manager(current_user: User = Depends(get_current_user)) -> User:
    """Exige administrador ou gerente_academia."""
    if current_user.role not in ("administrador", "gerente_academia"):
        _log_access_denied(current_user, "administrador|gerente_academia")
        raise ForbiddenError("Acesso negado. Apenas administradores ou gerentes de academia.")
    return current_user


def require_admin_or_professor(current_user: User = Depends(get_current_user)) -> User:
    """Exige administrador ou professor."""
    if current_user.role not in ("administrador", "professor"):
        _log_access_denied(current_user, "administrador|professor")
        raise ForbiddenError("Acesso negado. Apenas administradores ou professores.")
    return current_user


def require_admin_or_academy_access(current_user: User = Depends(get_current_user)) -> User:
    """Exige administrador, gerente_academia ou professor."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        _log_access_denied(current_user, "administrador|gerente_academia|professor")
        raise ForbiddenError("Acesso negado. Apenas administradores, gerentes de academia ou professores.")
    return current_user


def require_readonly_or_write(
    current_user: User = Depends(get_current_user),
    method: str = "GET",
) -> User:
    """Supervisor só leitura (GET); demais roles podem escrever."""
    if current_user.role == "supervisor" and method.upper() not in ("GET", "HEAD", "OPTIONS"):
        raise ForbiddenError("Acesso negado. Supervisores têm acesso apenas de leitura.")
    if current_user.role == "supervisor":
        return current_user
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado.")
    return current_user


def require_read_access(current_user: User = Depends(get_current_user)) -> User:
    """Leitura para admin, gerente, professor, supervisor ou aluno (ex.: posições para Reportar dificuldade)."""
    if current_user.role not in ("administrador", "gerente_academia", "professor", "supervisor", "aluno"):
        raise ForbiddenError("Acesso negado.")
    return current_user


def require_write_access(current_user: User = Depends(get_current_user)) -> User:
    """Escrita: apenas admin, gerente ou professor."""
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise ForbiddenError("Acesso negado. Apenas administradores, gerentes de academia ou professores.")
    return current_user


def verify_academy_access(
    current_user: User,
    resource_academy_id: str | None,
    allow_none: bool = False,
) -> None:
    """Verifica se o usuário tem acesso ao recurso da academia especificada."""
    if current_user.role == "administrador":
        return

    if resource_academy_id is None:
        if not allow_none:
            raise ForbiddenError("Acesso negado. Recurso não vinculado a uma academia.")
        return

    if current_user.academy_id is None:
        raise ForbiddenError("Acesso negado. Você não está vinculado a uma academia.")

    if str(resource_academy_id) != str(current_user.academy_id):
        logger.warning(
            "Tentativa de acesso cross-academy",
            extra={
                "user_id": str(current_user.id),
                "user_academy_id": str(current_user.academy_id),
                "target_academy_id": str(resource_academy_id),
            },
        )
        raise ForbiddenError("Acesso negado. Você só pode acessar recursos da sua academia.")
