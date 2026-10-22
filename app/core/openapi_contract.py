"""Detecta mudanças na API que quebram versões do app já instaladas.

Compara dois documentos OpenAPI (o snapshot salvo em docs/openapi_snapshot.json e o atual)
seguindo o contrato de compatibilidade do app Android:

- respostas (o que o app LÊ): campo não pode sumir, mudar de tipo, passar a aceitar null
  nem deixar de ser obrigatório; enum não ganha valor novo sem o app saber tratar;
- requisições (o que o app ENVIA): nenhum campo/parâmetro novo obrigatório, nada que o app
  já manda deixa de ser aceito;
- endpoint não some.

Mudanças aditivas (campo novo na resposta, endpoint novo, campo opcional novo) passam.
"""

from typing import Any

_SUCCESS_STATUSES = ("200", "201", "202")
_MAX_DEPTH = 12

Schema = dict[str, Any]


class _Spec:
    def __init__(self, doc: dict):
        self.doc = doc
        self.components = doc.get("components", {}).get("schemas", {})

    def resolve(self, schema: Schema | None) -> Schema:
        seen = 0
        while schema and "$ref" in schema and seen < _MAX_DEPTH:
            name = schema["$ref"].rsplit("/", 1)[-1]
            schema = self.components.get(name, {})
            seen += 1
        return schema or {}

    def variants(self, schema: Schema | None) -> list[Schema]:
        """Achata anyOf/oneOf/allOf de um item só em uma lista de schemas resolvidos."""
        schema = self.resolve(schema)
        for key in ("anyOf", "oneOf"):
            if key in schema:
                out: list[Schema] = []
                for sub in schema[key]:
                    out.extend(self.variants(sub))
                return out
        if "allOf" in schema and len(schema["allOf"]) == 1:
            return self.variants(schema["allOf"][0])
        return [schema]

    def types(self, schema: Schema | None) -> set[str]:
        out: set[str] = set()
        for v in self.variants(schema):
            t = v.get("type")
            if isinstance(t, list):
                out.update(t)
            elif t:
                out.add(t)
            elif "properties" in v:
                out.add("object")
            else:
                out.add("any")
        return out

    def enum(self, schema: Schema | None) -> set | None:
        values: set = set()
        found = False
        for v in self.variants(schema):
            if "enum" in v:
                found = True
                values.update(map(str, v["enum"]))
            elif "const" in v:
                found = True
                values.add(str(v["const"]))
        return values if found else None

    def object_view(self, schema: Schema | None) -> tuple[dict[str, Schema], set[str]]:
        props: dict[str, Schema] = {}
        required: set[str] = set()
        for v in self.variants(schema):
            props.update(v.get("properties", {}))
            required.update(v.get("required", []))
        return props, required

    def items(self, schema: Schema | None) -> Schema | None:
        for v in self.variants(schema):
            if "items" in v:
                return v["items"]
        return None


def _json_schema(container: dict | None) -> Schema | None:
    if not container:
        return None
    content = container.get("content", {})
    for media in ("application/json", "multipart/form-data", "application/x-www-form-urlencoded"):
        if media in content:
            return content[media].get("schema")
    return None


def _compare_response(old: _Spec, new: _Spec, o: Schema | None, n: Schema | None, where: str, errors: list, depth=0):
    if depth > _MAX_DEPTH:
        return
    old_types, new_types = old.types(o), new.types(n)
    if "any" in old_types or "any" in new_types:
        return
    added = new_types - old_types
    if added == {"null"}:
        errors.append(f"{where}: passou a poder ser null (o app antigo lê como obrigatório)")
    elif added:
        errors.append(f"{where}: tipo mudou de {sorted(old_types)} para {sorted(new_types)}")
        return

    old_enum, new_enum = old.enum(o), new.enum(n)
    if old_enum is not None and new_enum is not None and new_enum - old_enum:
        errors.append(f"{where}: enum ganhou valores novos {sorted(new_enum - old_enum)}")

    if "object" in old_types:
        old_props, old_req = old.object_view(o)
        new_props, new_req = new.object_view(n)
        for name, sub in old_props.items():
            if name not in new_props:
                errors.append(f"{where}.{name}: campo removido da resposta")
                continue
            if name in old_req and name not in new_req:
                errors.append(f"{where}.{name}: deixou de ser obrigatório na resposta")
            _compare_response(old, new, sub, new_props[name], f"{where}.{name}", errors, depth + 1)

    if "array" in old_types:
        _compare_response(old, new, old.items(o), new.items(n), f"{where}[]", errors, depth + 1)


def _compare_request(old: _Spec, new: _Spec, o: Schema | None, n: Schema | None, where: str, errors: list, depth=0):
    if depth > _MAX_DEPTH:
        return
    old_types, new_types = old.types(o), new.types(n)
    if "any" in old_types or "any" in new_types:
        return
    lost = old_types - new_types
    if lost:
        errors.append(f"{where}: deixou de aceitar {sorted(lost)}")
        return

    old_enum, new_enum = old.enum(o), new.enum(n)
    if old_enum is not None and new_enum is not None and old_enum - new_enum:
        errors.append(f"{where}: deixou de aceitar os valores {sorted(old_enum - new_enum)}")

    if "object" in old_types:
        old_props, old_req = old.object_view(o)
        new_props, new_req = new.object_view(n)
        for name in sorted(new_req - old_req):
            errors.append(f"{where}.{name}: campo novo obrigatório na requisição")
        for name, sub in old_props.items():
            if name not in new_props:
                errors.append(f"{where}.{name}: campo que o app envia foi removido")
                continue
            _compare_request(old, new, sub, new_props[name], f"{where}.{name}", errors, depth + 1)

    if "array" in old_types:
        _compare_request(old, new, old.items(o), new.items(n), f"{where}[]", errors, depth + 1)


def _params(op: dict) -> dict[tuple[str, str], dict]:
    return {(p.get("in", ""), p.get("name", "")): p for p in op.get("parameters", [])}


def find_breaking_changes(old_doc: dict, new_doc: dict) -> list[str]:
    """Lista legível das mudanças que quebram clientes antigos (vazia = compatível)."""
    old, new = _Spec(old_doc), _Spec(new_doc)
    errors: list[str] = []
    new_paths = new_doc.get("paths", {})

    for path, methods in sorted(old_doc.get("paths", {}).items()):
        for method, old_op in sorted(methods.items()):
            label = f"{method.upper()} {path}"
            new_op = new_paths.get(path, {}).get(method)
            if new_op is None:
                errors.append(f"{label}: endpoint removido")
                continue

            old_params, new_params = _params(old_op), _params(new_op)
            for key, param in sorted(new_params.items()):
                if param.get("required") and key not in old_params:
                    errors.append(f"{label}: parâmetro novo obrigatório {key[0]}:{key[1]}")
            for key, param in sorted(old_params.items()):
                if key not in new_params:
                    errors.append(f"{label}: parâmetro removido {key[0]}:{key[1]}")
                    continue
                _compare_request(
                    old, new, param.get("schema"), new_params[key].get("schema"), f"{label} {key[1]}", errors
                )

            old_body, new_body = old_op.get("requestBody"), new_op.get("requestBody")
            if new_body and new_body.get("required") and not old_body:
                errors.append(f"{label}: passou a exigir corpo na requisição")
            if old_body and new_body:
                _compare_request(old, new, _json_schema(old_body), _json_schema(new_body), f"{label} body", errors)

            for status in _SUCCESS_STATUSES:
                old_resp = old_op.get("responses", {}).get(status)
                if not old_resp:
                    continue
                new_resp = new_op.get("responses", {}).get(status)
                if not new_resp:
                    errors.append(f"{label}: resposta {status} removida")
                    continue
                _compare_response(
                    old, new, _json_schema(old_resp), _json_schema(new_resp), f"{label} → {status}", errors
                )
    return errors
