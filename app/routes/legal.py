"""Documentos legais públicos (Termos, Política de Privacidade, Aviso de Biometria).

Servidos pela API (independente do build do Flutter). A fonte da verdade são os
arquivos Markdown em ``docs/legal/`` (versionados no git). Endpoints:

- ``GET /legal/{slug}``        → JSON (Markdown + versão) para renderização no app
- ``GET /legal/{slug}/view``   → HTML estilizado para publicação/consulta no navegador
"""

import html
import re
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from app.config import settings
from app.core.exceptions import NotFoundError
from app.schemas.legal import LegalDocumentResponse

router = APIRouter()

_LEGAL_DIR = Path(__file__).resolve().parents[2] / "docs" / "legal"

_DOCS: dict[str, dict[str, str]] = {
    "privacy": {
        "title": "Política de Privacidade",
        "filename": "POLITICA_PRIVACIDADE.md",
        "version": settings.LEGAL_PRIVACY_VERSION,
    },
    "terms": {
        "title": "Termos de Uso",
        "filename": "TERMOS_DE_USO.md",
        "version": settings.LEGAL_TERMS_VERSION,
    },
    "biometric": {
        "title": "Aviso de Tratamento de Dado Biométrico",
        "filename": "AVISO_BIOMETRIA.md",
        "version": settings.LEGAL_BIOMETRIC_VERSION,
    },
}


@lru_cache(maxsize=8)
def _read_doc(filename: str) -> str:
    path = _LEGAL_DIR / filename
    if not path.exists():
        raise NotFoundError("Documento legal não encontrado.")
    return path.read_text(encoding="utf-8")


def _markdown_to_html(md: str) -> str:
    """Conversor mínimo de Markdown para HTML (conteúdo controlado nos docs do projeto)."""
    out: list[str] = []
    in_list = False
    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            if in_list:
                out.append("</ul>")
                in_list = False
            continue
        if line.strip() == "---":
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<hr>")
            continue
        heading = re.match(r"^(#{1,4})\s+(.*)$", line)
        if heading:
            if in_list:
                out.append("</ul>")
                in_list = False
            level = len(heading.group(1))
            out.append(f"<h{level}>{_inline(heading.group(2))}</h{level}>")
            continue
        bullet = re.match(r"^[-*]\s+(.*)$", line.strip())
        if bullet:
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{_inline(bullet.group(1))}</li>")
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        out.append(f"<p>{_inline(line.strip())}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def _inline(text: str) -> str:
    """Escapa HTML e aplica **negrito**, *itálico* e [link](url)."""
    text = html.escape(text)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    return text


def _get_meta(slug: str) -> dict[str, str]:
    meta = _DOCS.get(slug)
    if not meta:
        raise NotFoundError("Documento legal não encontrado.")
    return meta


@router.get("/{slug}", response_model=LegalDocumentResponse)
def get_legal_document(slug: str):
    """Retorna o documento legal em Markdown + metadados de versão."""
    meta = _get_meta(slug)
    return LegalDocumentResponse(
        slug=slug,
        title=meta["title"],
        version=meta["version"],
        contact_email=settings.DPO_CONTACT_EMAIL,
        content_markdown=_read_doc(meta["filename"]),
    )


@router.get("/{slug}/view", response_class=HTMLResponse, include_in_schema=False)
def view_legal_document(slug: str):
    """Página HTML estilizada do documento (para publicação/consulta no navegador)."""
    meta = _get_meta(slug)
    body = _markdown_to_html(_read_doc(meta["filename"]))
    title = html.escape(meta["title"])
    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} — Octogrip</title>
  <style>
    body {{ font-family: system-ui, -apple-system, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 24px; color: #1a1a2e; line-height: 1.6; }}
    h1 {{ font-size: 1.8rem; }}
    h2 {{ font-size: 1.3rem; margin-top: 2rem; border-bottom: 1px solid #eee; padding-bottom: 4px; }}
    h3 {{ font-size: 1.1rem; margin-top: 1.5rem; }}
    a {{ color: #46A302; }}
    hr {{ border: none; border-top: 1px solid #eee; margin: 2rem 0; }}
    .meta {{ color: #888; font-size: .9rem; margin-bottom: 2rem; }}
  </style>
</head>
<body>
  <p class="meta">Versão {html.escape(meta["version"])} · Contato do Encarregado: {html.escape(settings.DPO_CONTACT_EMAIL)}</p>
  {body}
</body>
</html>"""
