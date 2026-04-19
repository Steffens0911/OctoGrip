#!/usr/bin/env python3
"""
Verifica o fluxo mínimo de push na API (login, registo de token, endpoint de broadcast).

Uso (API local Docker na porta 8001):
  python scripts/verify_push_setup.py
  python scripts/verify_push_setup.py --base-url https://api.seudominio.com --email admin@jjb.com --password saas

Interpretação:
  - 404 em /admin/push_broadcast → imagem da API antiga; faça rebuild/redeploy.
  - 503 no broadcast → falta FIREBASE_PROJECT_ID / FIREBASE_SERVICE_ACCOUNT_PATH no servidor.
  - target_tokens > 0 mas sent == 0 → tokens na BD inválidos ou FCM a rejeitar (normal com token de teste).
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request


def _post(url: str, body: dict | None, token: str | None = None, method: str = "POST") -> tuple[int, str]:
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def main() -> int:
    p = argparse.ArgumentParser(description="Diagnóstico rápido FCM/push na API OctoGrip.")
    p.add_argument("--base-url", default="http://127.0.0.1:8001", help="URL base da API (sem barra final)")
    p.add_argument("--email", default="admin@jjb.com")
    p.add_argument("--password", default="saas")
    args = p.parse_args()
    base = args.base_url.rstrip("/")

    code, body = _post(f"{base}/health", None, method="GET")
    if code != 200:
        print(f"ERRO: GET /health -> {code} {body[:200]}")
        return 1
    print("OK: GET /health -> 200")

    code, body = _post(f"{base}/auth/login", {"email": args.email, "password": args.password})
    if code != 200:
        print(f"ERRO: login -> {code} {body[:400]}")
        return 1
    token = json.loads(body)["access_token"]
    print("OK: POST /auth/login -> JWT")

    code, body = _post(
        f"{base}/me/push_token",
        {"token": "verify_push_script_token_1234567890", "platform": "web"},
        token,
    )
    if code not in (200, 204):
        print(f"ERRO: POST /me/push_token -> {code} {body[:400]}")
        return 1
    print("OK: POST /me/push_token ->", code)

    code, body = _post(
        f"{base}/admin/push_broadcast",
        {"title": "Verificação", "body": "Script verify_push_setup.py"},
        token,
    )
    if code == 404:
        print("ERRO: POST /admin/push_broadcast -> 404 (codigo da API sem esta rota; rebuild/redeploy).")
        return 1
    if code == 503:
        print("AVISO: POST /admin/push_broadcast -> 503 (Firebase nao configurado no servidor).")
        print(body[:500])
        return 2
    if code != 200:
        print(f"ERRO: POST /admin/push_broadcast -> {code} {body[:500]}")
        return 1
    summary = json.loads(body)
    print("OK: POST /admin/push_broadcast ->", summary)
    if summary.get("target_tokens", 0) == 0:
        print(
            "NOTA: target_tokens=0 - nenhum dispositivo na tabela user_device_tokens "
            "(faca login num cliente com FCM)."
        )
    elif summary.get("sent", 0) == 0:
        print(
            "NOTA: sent=0 - FCM nao aceitou o envio (tokens de teste / JSON service account / project_id). "
            "Confira FIREBASE_* no servidor."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
