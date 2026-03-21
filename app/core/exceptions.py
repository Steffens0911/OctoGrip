"""
Exceções de domínio da aplicação.
Centralizadas para reuso e mapeamento único para HTTP (exception handlers).
"""


class AppError(Exception):
    """Base para exceções de domínio (opcional: detail e status_code)."""

    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class AuthenticationError(AppError):
    """Falha de autenticação (401)."""

    def __init__(self, message: str = "Token de autenticação ausente ou inválido."):
        super().__init__(message, status_code=401)


class ForbiddenError(AppError):
    """Acesso negado."""

    def __init__(self, message: str = "Acesso negado."):
        super().__init__(message, status_code=403)


# --- Not Found (404) ---


class NotFoundError(AppError):
    """Recurso não encontrado."""

    def __init__(self, message: str = "Recurso não encontrado"):
        super().__init__(message, status_code=404)


class UserNotFoundError(NotFoundError):
    def __init__(self, message: str = "Usuário não encontrado."):
        super().__init__(message)


class LessonNotFoundError(NotFoundError):
    def __init__(self, message: str = "Lição não encontrada."):
        super().__init__(message)


class PositionNotFoundError(NotFoundError):
    def __init__(self, message: str = "Posição não encontrada."):
        super().__init__(message)


class TechniqueNotFoundError(NotFoundError):
    def __init__(self, message: str = "Técnica não encontrada."):
        super().__init__(message)


class AcademyNotFoundError(NotFoundError):
    def __init__(self, message: str = "Academia não encontrada."):
        super().__init__(message)


class MissionNotFoundError(NotFoundError):
    def __init__(self, message: str = "Missão não encontrada."):
        super().__init__(message)


class ProfessorNotFoundError(NotFoundError):
    def __init__(self, message: str = "Professor não encontrado."):
        super().__init__(message)


class PartnerNotFoundError(NotFoundError):
    def __init__(self, message: str = "Parceiro não encontrado."):
        super().__init__(message)


class TrophyNotFoundError(NotFoundError):
    def __init__(self, message: str = "Troféu não encontrado."):
        super().__init__(message)


# --- Conflict (409) ---


class AlreadyCompletedError(AppError):
    """Lição já concluída por este usuário."""

    def __init__(self, message: str = "Esta lição já foi concluída por este usuário."):
        super().__init__(message, status_code=409)


class ConflictError(AppError):
    """Recurso já existe ou operação conflitante."""

    def __init__(self, message: str = "Recurso já existe."):
        super().__init__(message, status_code=409)
