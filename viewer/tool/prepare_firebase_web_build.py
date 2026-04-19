#!/usr/bin/env python3
"""Prepara FCM Web no Docker: substitui placeholders em web/firebase-messaging-sw.js e
gera tool/dart_define_web.json para `flutter build --dart-define-from-file=...`,
evitando que caracteres especiais nas variáveis de ambiente partam o shell/sed."""

from __future__ import annotations

import json
import os
from pathlib import Path

# Defaults alinhados a lib/firebase_options.dart (repo octogrip).
_DEFAULTS = {
    "FIREBASE_WEB_API_KEY": "AIzaSyAby3LjFqiQysgqFJF3TDkFyIQbj7XeD2A",
    "FIREBASE_MESSAGING_SENDER_ID": "914963189561",
    "FIREBASE_PROJECT_ID": "octogrip",
    "FIREBASE_AUTH_DOMAIN": "octogrip.firebaseapp.com",
    "FIREBASE_STORAGE_BUCKET": "octogrip.firebasestorage.app",
}


def _env(name: str) -> str:
    v = os.environ.get(name)
    if v is None or not str(v).strip():
        return _DEFAULTS.get(name, "")
    return str(v).strip().strip('"').strip("'")


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    sw_path = root / "web" / "firebase-messaging-sw.js"
    out_json = root / "tool" / "dart_define_web.json"

    api_key = _env("FIREBASE_WEB_API_KEY") or _DEFAULTS["FIREBASE_WEB_API_KEY"]
    app_id = _env("FIREBASE_WEB_APP_ID")
    sender = _env("FIREBASE_MESSAGING_SENDER_ID") or _DEFAULTS["FIREBASE_MESSAGING_SENDER_ID"]
    project = _env("FIREBASE_PROJECT_ID") or _DEFAULTS["FIREBASE_PROJECT_ID"]
    auth = _env("FIREBASE_AUTH_DOMAIN") or _DEFAULTS["FIREBASE_AUTH_DOMAIN"]
    bucket = _env("FIREBASE_STORAGE_BUCKET") or _DEFAULTS["FIREBASE_STORAGE_BUCKET"]

    text = sw_path.read_text(encoding="utf-8")
    text = text.replace("__FIREBASE_WEB_API_KEY__", api_key)
    text = text.replace("__FIREBASE_WEB_APP_ID__", app_id or "__FIREBASE_WEB_APP_ID__")
    text = text.replace("__FIREBASE_MESSAGING_SENDER_ID__", sender)
    text = text.replace("__FIREBASE_PROJECT_ID__", project)
    text = text.replace("__FIREBASE_AUTH_DOMAIN__", auth)
    text = text.replace("__FIREBASE_STORAGE_BUCKET__", bucket)
    sw_path.write_text(text, encoding="utf-8")

    api_base = os.environ.get("API_BASE_URL", "http://localhost:8000")
    if isinstance(api_base, str):
        api_base = api_base.strip()

    defines: dict[str, str] = {
        "API_BASE_URL": api_base,
        "FIREBASE_WEB_APP_ID": app_id,
        "FIREBASE_WEB_API_KEY": api_key,
        "FIREBASE_MESSAGING_SENDER_ID": sender,
        "FIREBASE_PROJECT_ID": project,
        "FIREBASE_AUTH_DOMAIN": auth,
        "FIREBASE_STORAGE_BUCKET": bucket,
        "FCM_VAPID_KEY": os.environ.get("FCM_VAPID_KEY", "") or "",
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(defines, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "[prepare_firebase_web_build] wrote tool/dart_define_web.json; "
        f"app_id_set={'yes' if app_id else 'no'}; "
        f"custom_api_key={'yes' if os.environ.get('FIREBASE_WEB_API_KEY', '').strip() else 'no'}"
    )


if __name__ == "__main__":
    main()
