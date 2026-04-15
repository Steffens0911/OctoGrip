"""Normalização de telefone BR e geração de URL WhatsApp para anúncios do marketplace."""
from __future__ import annotations

import re
from urllib.parse import quote

# Texto fixo embutido no parâmetro `text=` do wa.me (inclui título do produto).
MARKETPLACE_WHATSAPP_MESSAGE_TEMPLATE = (
    'Olá! Tenho interesse no produto "{title}" (anúncio FlowRoll).'
)


def normalize_br_whatsapp_phone(ddd: str | None, number: str | None) -> str | None:
    """Retorna dígitos `55` + DDD + número ou None se ambos vazios. Levanta ValueError se parcial/ inválido."""
    d = (ddd or "").strip().replace(" ", "")
    n = (number or "").strip().replace(" ", "").replace("-", "")
    if not d and not n:
        return None
    if not d or not n:
        raise ValueError("Informe DDD e número juntos, ou deixe os dois vazios.")
    if not d.isdigit() or len(d) != 2:
        raise ValueError("DDD deve ter exatamente 2 dígitos.")
    if not n.isdigit() or len(n) not in (8, 9):
        raise ValueError("Número deve ter 8 ou 9 dígitos (sem DDD).")
    return f"55{d}{n}"


def split_br_phone_for_editor(phone: str | None) -> tuple[str | None, str | None]:
    """Extrai DDD e número local a partir de dígitos armazenados (55 + DDD + número)."""
    if not phone or not str(phone).strip():
        return None, None
    digits = re.sub(r"\D", "", str(phone))
    if digits.startswith("55") and len(digits) >= 12:
        rest = digits[2:]
        return rest[:2], rest[2:]
    if len(digits) >= 10:
        return digits[:2], digits[2:]
    return None, None


def build_whatsapp_message(title: str) -> str:
    return MARKETPLACE_WHATSAPP_MESSAGE_TEMPLATE.format(title=title.strip() or "produto")


def build_whatsapp_url(*, phone: str, title: str) -> str:
    """Monta URL wa.me com texto pré-definido (codificado)."""
    digits = re.sub(r"\D", "", phone)
    if not digits:
        raise ValueError("Telefone vazio.")
    msg = build_whatsapp_message(title)
    return f"https://wa.me/{digits}?text={quote(msg, safe='')}"
