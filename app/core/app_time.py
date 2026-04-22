"""
Fuso do aplicativo para regras de calendário (hoje, semana ISO, sequência de login, etc.).

Instantes no banco continuam em UTC; aqui só derivamos datas/limites do dia no fuso configurado
(padrão America/Sao_Paulo).
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from functools import lru_cache
from zoneinfo import ZoneInfo

from app.config import settings


@lru_cache
def get_app_tz() -> ZoneInfo:
    return ZoneInfo(settings.APP_TIMEZONE)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def now_in_app_tz(utc_dt: datetime | None = None) -> datetime:
    """Converte instante UTC para o fuso do app (ou retorna 'agora' nesse fuso)."""
    dt = utc_dt if utc_dt is not None else utc_now()
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(get_app_tz())


def today_in_app_tz(utc_dt: datetime | None = None) -> date:
    """Data de calendário atual no fuso do app."""
    return now_in_app_tz(utc_dt).date()


def calendar_date_in_app_tz(utc_dt: datetime) -> date:
    """Data de calendário no fuso do app para um instante UTC (ex.: last_login_at)."""
    if utc_dt.tzinfo is None:
        utc_dt = utc_dt.replace(tzinfo=timezone.utc)
    return utc_dt.astimezone(get_app_tz()).date()


def combine_local_date_start_utc(d: date) -> datetime:
    """00:00 do dia `d` no fuso do app, como datetime com tz UTC."""
    return datetime.combine(d, time.min, tzinfo=get_app_tz()).astimezone(timezone.utc)


def combine_local_date_end_utc(d: date) -> datetime:
    """Fim do dia `d` no fuso do app (23:59:59.999999), como datetime com tz UTC."""
    return datetime.combine(
        d, time.max.replace(microsecond=999999), tzinfo=get_app_tz()
    ).astimezone(timezone.utc)


def combine_local_date_exclusive_end_utc(d: date) -> datetime:
    """00:00 do dia seguinte a `d` no fuso do app, em UTC (limite superior exclusivo para intervalos)."""
    return datetime.combine(d + timedelta(days=1), time.min, tzinfo=get_app_tz()).astimezone(
        timezone.utc
    )
