"""Dependências FastAPI para autorização baseada em roles."""
from fastapi import Depends, HTTPException, status

from app.core.auth_deps import get_current_user
from app.models import User


def require_role(allowed_roles: list[str]):
    """
    Factory que retorna uma dependência que exige que o usuário tenha um dos roles permitidos.
    
    Uso:
        @router.get("/admin")
        def admin_route(user: User = Depends(require_role(["administrador"]))):
            ...
    """
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Acesso negado. Roles permitidos: {', '.join(allowed_roles)}",
            )
        return current_user
    return role_checker


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Exige que o usuário seja administrador."""
    if current_user.role != "administrador":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Apenas administradores podem acessar este recurso.",
        )
    return current_user


def require_admin_or_manager(current_user: User = Depends(get_current_user)) -> User:
    """Exige que o usuário seja administrador ou gerente_academia."""
    if current_user.role not in ("administrador", "gerente_academia"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Apenas administradores ou gerentes de academia podem acessar este recurso.",
        )
    return current_user


def require_admin_or_professor(current_user: User = Depends(get_current_user)) -> User:
    """Exige que o usuário seja administrador ou professor."""
    if current_user.role not in ("administrador", "professor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Apenas administradores ou professores podem acessar este recurso.",
        )
    return current_user


def require_admin_or_academy_access(current_user: User = Depends(get_current_user)) -> User:
    """
    Exige que o usuário seja administrador, gerente_academia ou professor.
    Usado para recursos relacionados à academia (técnicas, posições, lições, missões, etc).
    """
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Apenas administradores, gerentes de academia ou professores podem acessar este recurso.",
        )
    return current_user


def require_readonly_or_write(
    current_user: User = Depends(get_current_user),
    method: str = "GET",
) -> User:
    """
    Permite supervisor apenas leitura (GET), outros roles podem escrever.
    Usado em rotas que supervisor pode ler mas não modificar.
    """
    if current_user.role == "supervisor" and method.upper() not in ("GET", "HEAD", "OPTIONS"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Supervisores têm acesso apenas de leitura.",
        )
    # Para GET, supervisor pode acessar se tiver permissão de leitura
    if current_user.role == "supervisor":
        return current_user
    # Para outros métodos, verificar se tem acesso de escrita
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado.",
        )
    return current_user


def require_read_access(current_user: User = Depends(get_current_user)) -> User:
    """
    Permite acesso de leitura para supervisor, admin, gerente ou professor.
    Usado em rotas GET que supervisor pode acessar.
    """
    if current_user.role not in ("administrador", "gerente_academia", "professor", "supervisor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado.",
        )
    return current_user


def require_write_access(current_user: User = Depends(get_current_user)) -> User:
    """
    Exige acesso de escrita: apenas admin, gerente ou professor.
    Usado em rotas POST, PUT, DELETE.
    """
    if current_user.role not in ("administrador", "gerente_academia", "professor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado. Apenas administradores, gerentes de academia ou professores podem modificar este recurso.",
        )
    return current_user
