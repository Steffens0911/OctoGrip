"""Semana ISO (ano + número da semana) para escolha de kit semanal."""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone


def iso_week_key_for_date(d: date | None = None) -> tuple[int, int]:
    """Retorna (iso_year, iso_week_number) para a data (default: hoje em UTC)."""
    if d is None:
        d = datetime.now(timezone.utc).date()
    y, w, _ = d.isocalendar()
    return (y, w)


def date_range_for_iso_week(iso_year: int, iso_week: int) -> tuple[date, date]:
    """Segunda a domingo (inclusive) da semana ISO."""
    monday = date.fromisocalendar(iso_year, iso_week, 1)
    sunday = monday + timedelta(days=6)
    return monday, sunday


def utc_datetime_bounds_for_iso_week(iso_year: int, iso_week: int) -> tuple[datetime, datetime]:
    """Limites [start, end) em UTC para consultas em completed_at/confirmed_at."""
    monday, sunday = date_range_for_iso_week(iso_year, iso_week)
    start = datetime(monday.year, monday.month, monday.day, tzinfo=timezone.utc)
    end = datetime(sunday.year, sunday.month, sunday.day, tzinfo=timezone.utc) + timedelta(days=1)
    return start, end
