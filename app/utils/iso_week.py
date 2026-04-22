"""Semana ISO (ano + número da semana) para escolha de kit semanal."""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from app.core.app_time import get_app_tz, today_in_app_tz


def iso_week_key_for_date(d: date | None = None) -> tuple[int, int]:
    """Retorna (iso_year, iso_week_number) para a data (default: hoje no fuso APP_TIMEZONE)."""
    if d is None:
        d = today_in_app_tz()
    y, w, _ = d.isocalendar()
    return (y, w)


def date_range_for_iso_week(iso_year: int, iso_week: int) -> tuple[date, date]:
    """Segunda a domingo (inclusive) da semana ISO."""
    monday = date.fromisocalendar(iso_year, iso_week, 1)
    sunday = monday + timedelta(days=6)
    return monday, sunday


def utc_datetime_bounds_for_iso_week(iso_year: int, iso_week: int) -> tuple[datetime, datetime]:
    """
    Limites [start, end) em UTC para consultas em completed_at/confirmed_at.

    A semana ISO é ancorada nos dias de calendário no fuso APP_TIMEZONE:
    segunda 00:00 até a segunda seguinte 00:00 (exclusive), ambos expressos em UTC.
    """
    monday, _sunday = date_range_for_iso_week(iso_year, iso_week)
    tz = get_app_tz()
    start_local = datetime.combine(monday, time.min, tzinfo=tz)
    end_local = datetime.combine(monday + timedelta(days=7), time.min, tzinfo=tz)
    return start_local.astimezone(timezone.utc), end_local.astimezone(timezone.utc)
