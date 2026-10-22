"""Contrato da API com o app instalado nos celulares (docs/openapi_snapshot.json).

Falhou? Veja a mensagem:
- "quebra": a mudança derruba versões do app já instaladas → siga o ciclo de depreciação
  (docs/android_release.md) ou torne a mudança aditiva;
- "snapshot desatualizado": mudança aditiva → rode `python scripts/update_openapi_snapshot.py`.
"""

import json
from copy import deepcopy
from pathlib import Path

import pytest

from app.core.openapi_contract import find_breaking_changes
from app.main import app

SNAPSHOT = Path(__file__).resolve().parent.parent / "docs" / "openapi_snapshot.json"


def _current() -> dict:
    # Ida e volta em JSON para comparar exatamente o que o script grava.
    return json.loads(json.dumps(app.openapi(), ensure_ascii=False, sort_keys=True))


def _snapshot() -> dict:
    return json.loads(SNAPSHOT.read_text(encoding="utf-8"))


def test_api_has_no_breaking_changes_for_installed_apps():
    breaking = find_breaking_changes(_snapshot(), _current())
    assert not breaking, "Mudanças que quebram o app já instalado:\n" + "\n".join(f"  - {b}" for b in breaking)


def test_openapi_snapshot_is_up_to_date():
    assert _snapshot() == _current(), (
        "Snapshot desatualizado (mudança aditiva). Rode: python scripts/update_openapi_snapshot.py"
    )


# ---------------------------------------------------------------------------
# Regras do comparador, com um contrato mínimo
# ---------------------------------------------------------------------------

_BASE = {
    "paths": {
        "/me": {
            "get": {
                "parameters": [{"in": "query", "name": "lang", "required": False, "schema": {"type": "string"}}],
                "responses": {
                    "200": {"content": {"application/json": {"schema": {"$ref": "#/components/schemas/Me"}}}}
                },
            },
            "put": {
                "requestBody": {
                    "required": True,
                    "content": {"application/json": {"schema": {"$ref": "#/components/schemas/MeUpdate"}}},
                },
                "responses": {
                    "200": {"content": {"application/json": {"schema": {"$ref": "#/components/schemas/Me"}}}}
                },
            },
        }
    },
    "components": {
        "schemas": {
            "Me": {
                "type": "object",
                "required": ["name", "role", "points"],
                "properties": {
                    "name": {"type": "string"},
                    "role": {"type": "string", "enum": ["aluno", "professor"]},
                    "points": {"type": "integer"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                },
            },
            "MeUpdate": {
                "type": "object",
                "required": ["name"],
                "properties": {"name": {"type": "string"}, "bio": {"anyOf": [{"type": "string"}, {"type": "null"}]}},
            },
        }
    },
}


def _changed(mutate) -> list[str]:
    new = deepcopy(_BASE)
    mutate(new)
    return find_breaking_changes(_BASE, new)


def _me(doc):
    return doc["components"]["schemas"]["Me"]


def _me_update(doc):
    return doc["components"]["schemas"]["MeUpdate"]


def test_identical_contract_has_no_breaks():
    assert find_breaking_changes(_BASE, deepcopy(_BASE)) == []


@pytest.mark.parametrize(
    "mutate",
    [
        pytest.param(lambda d: _me(d)["properties"].update(avatar={"type": "string"}), id="campo novo na resposta"),
        pytest.param(lambda d: d["paths"].update({"/novo": {"get": {"responses": {}}}}), id="endpoint novo"),
        pytest.param(lambda d: _me_update(d)["properties"].update(city={"type": "string"}), id="campo opcional novo"),
        pytest.param(lambda d: _me_update(d)["required"].remove("name"), id="campo da requisição vira opcional"),
        # o app antigo continua entendendo os valores que sobraram
        pytest.param(lambda d: _me(d)["properties"]["role"]["enum"].remove("professor"), id="enum da resposta encolhe"),
    ],
)
def test_additive_changes_are_allowed(mutate):
    new = deepcopy(_BASE)
    mutate(new)
    assert find_breaking_changes(_BASE, new) == []


@pytest.mark.parametrize(
    ("mutate", "expected"),
    [
        (lambda d: _me(d)["properties"].pop("points"), "campo removido"),
        (lambda d: _me(d)["properties"].update(points={"type": "string"}), "tipo mudou"),
        (
            lambda d: _me(d)["properties"].update(name={"anyOf": [{"type": "string"}, {"type": "null"}]}),
            "passou a poder ser null",
        ),
        (lambda d: _me(d)["required"].remove("name"), "deixou de ser obrigatório"),
        (lambda d: _me(d)["properties"]["role"]["enum"].append("gerente"), "enum ganhou valores novos"),
        (lambda d: _me(d)["properties"]["tags"].update(items={"type": "integer"}), "tags[]"),
        (lambda d: _me_update(d)["required"].append("bio"), "campo novo obrigatório"),
        (lambda d: _me_update(d)["properties"].pop("bio"), "campo que o app envia foi removido"),
        (lambda d: d["paths"]["/me"].pop("put"), "endpoint removido"),
        (
            lambda d: d["paths"]["/me"]["get"]["parameters"].append(
                {"in": "query", "name": "academy", "required": True, "schema": {"type": "string"}}
            ),
            "parâmetro novo obrigatório",
        ),
        (lambda d: d["paths"]["/me"]["get"]["parameters"].clear(), "parâmetro removido"),
    ],
)
def test_breaking_changes_are_detected(mutate, expected):
    breaking = _changed(mutate)
    assert any(expected in b for b in breaking), breaking
