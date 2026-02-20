"""Testes de configuração."""
from app.config import settings, _DEFAULT_JWT_SECRET


def test_settings_loaded():
    assert settings.DATABASE_URL is not None
    assert settings.JWT_ALGORITHM == "HS256"
    assert settings.DB_POOL_SIZE >= 1
    assert settings.DB_MAX_OVERFLOW >= 0


def test_default_jwt_secret_warning():
    assert settings.JWT_SECRET == _DEFAULT_JWT_SECRET or len(settings.JWT_SECRET) > 10


def test_cors_origins_is_list():
    assert isinstance(settings.CORS_ORIGINS, list)
    assert len(settings.CORS_ORIGINS) >= 1


def test_login_rate_limit_format():
    assert "/" in settings.LOGIN_RATE_LIMIT
