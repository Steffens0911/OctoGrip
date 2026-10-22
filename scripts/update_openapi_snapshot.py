#!/usr/bin/env python3
"""Atualiza docs/openapi_snapshot.json (contrato da API com o app instalado nos celulares).

Uso:
    python scripts/update_openapi_snapshot.py           # só aceita mudanças aditivas
    python scripts/update_openapi_snapshot.py --force   # aceita quebra (ciclo de depreciação concluído)

Rode depois de qualquer mudança de rota ou schema; o teste tests/test_openapi_contract.py falha
enquanto o snapshot estiver desatualizado. Ver docs/android_release.md.
"""

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / "docs" / "openapi_snapshot.json"

sys.path.insert(0, str(ROOT))
os.environ.setdefault("SEED_ON_STARTUP", "false")


def dump(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="grava mesmo com mudanças que quebram o app antigo")
    args = parser.parse_args()

    from app.core.openapi_contract import find_breaking_changes
    from app.main import app

    current = json.loads(dump(app.openapi()))
    if SNAPSHOT.exists():
        breaking = find_breaking_changes(json.loads(SNAPSHOT.read_text(encoding="utf-8")), current)
        if breaking and not args.force:
            print("Mudanças que quebram versões do app já instaladas:")
            for line in breaking:
                print(f"  - {line}")
            print("\nSiga o ciclo de depreciação; depois de subir a versão mínima, rode com --force.")
            return 1

    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(dump(current), encoding="utf-8", newline="\n")
    print(f"Snapshot atualizado: {SNAPSHOT.relative_to(ROOT)} ({len(current.get('paths', {}))} rotas)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
