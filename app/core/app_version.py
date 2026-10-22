"""Versão do app cliente (headers X-App-Version / X-App-Platform).

Formato igual ao do pubspec.yaml: ``MAIOR.MENOR.CORREÇÃO+BUILD`` (ex.: ``1.3.0+12``).
O ``+BUILD`` é opcional; sem ele vale 0, então ``min_version = 1.3.0`` aceita qualquer build 1.3.0.
"""

import re

APP_VERSION_HEADER = "X-App-Version"
APP_PLATFORM_HEADER = "X-App-Platform"

_VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$")

AppVersion = tuple[int, int, int, int]


def parse_app_version(raw: str | None) -> AppVersion | None:
    """``"1.3.0+12"`` → ``(1, 3, 0, 12)``; formato inválido → None (cliente tratado como sem versão)."""
    if not raw:
        return None
    match = _VERSION_RE.match(raw.strip())
    if not match:
        return None
    major, minor, patch, build = match.groups()
    return int(major), int(minor), int(patch), int(build or 0)


def is_valid_app_version(raw: str) -> bool:
    return parse_app_version(raw) is not None


def is_version_below(version: str | None, minimum: str | None) -> bool:
    """True só quando as duas versões são válidas e ``version < minimum``.

    Versão ausente ou malformada nunca é bloqueada: a web e apps antigos sem o header seguem funcionando.
    """
    current = parse_app_version(version)
    required = parse_app_version(minimum)
    if current is None or required is None:
        return False
    return current < required


def normalize_platform(raw: str | None) -> str | None:
    if not raw:
        return None
    value = raw.strip().lower()
    return value or None
