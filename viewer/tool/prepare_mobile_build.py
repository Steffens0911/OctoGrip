#!/usr/bin/env python3
"""Gera tool/dart_define_mobile.json para `flutter build appbundle --dart-define-from-file=...`.

Usado pelo workflow build-mobile.yml. O Firebase no Android vem de android/app/google-services.json,
então aqui só entra o que o app lê via String.fromEnvironment."""

from __future__ import annotations

import json
import os
from pathlib import Path

_DEFAULT_API_BASE_URL = "https://api.octogrip.com.br"


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out_json = root / "tool" / "dart_define_mobile.json"

    api_base = (os.environ.get("API_BASE_URL") or "").strip().strip('"').strip("'")
    if not api_base:
        api_base = _DEFAULT_API_BASE_URL
    if not api_base.startswith("https://"):
        # App de loja nunca fala com a API sem TLS (o Android bloqueia cleartext por padrão).
        raise SystemExit(f"[prepare_mobile_build] API_BASE_URL precisa ser https:// (recebido: {api_base!r})")

    defines: dict[str, str] = {
        "API_BASE_URL": api_base.rstrip("/"),
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(defines, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "[prepare_mobile_build] wrote tool/dart_define_mobile.json; "
        f"custom_api_base={'yes' if os.environ.get('API_BASE_URL', '').strip() else 'no'}"
    )


if __name__ == "__main__":
    main()
