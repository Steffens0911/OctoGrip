# Boas Práticas – Análise e Checklist

## 1. Segue padrões do framework?

### FastAPI (backend)

**O que está alinhado:**

- **Rotas**: Uso de `async def` para handlers, `Depends()` para injeção de dependências (get_db, get_current_user, require_admin, etc.).
- **Schemas**: Pydantic para validação de entrada/saída; `response_model` nos endpoints; `EmailStr`, `Field()` onde faz sentido.
- **Estrutura**: Separação routes / services / schemas / models; exceções de domínio centralizadas em `app/core/exceptions.py` mapeadas em `main.py`.
- **Configuração**: `pydantic-settings` para variáveis de ambiente; lifespan para startup (migrations, seed, logging, Sentry).

**Recomendações:**

- Manter um único padrão de nomenclatura de rotas (ex.: snake_case nos nomes das funções).
- Documentar endpoints sensíveis com `summary`/`description` e tags consistentes (já usado em vários lugares).
- Exception handlers que retornam `JSONResponse`: considerar tipo de retorno explícito `-> JSONResponse` para clareza (opcional).

### Flutter (viewer)

- Seguir convenções do projeto (pastas por feature, serviços compartilhados).
- Manter injeção de dependências e estado de forma consistente com o que já existe.

---

## 2. Tipagem correta?

**O que está bom:**

- **Services**: Funções com tipos explícitos para parâmetros e retorno (`AsyncSession`, `UUID`, `User | None`, `list[User]`, etc.).
- **Schemas**: Campos tipados com Pydantic; uso de `EmailStr`, `UUID` onde aplicável.
- **Models**: SQLAlchemy com tipos de coluna definidos.
- **Config**: `Settings` com tipos para todas as variáveis.

**Sugestões:**

- Rotas: a maioria já usa tipos nos parâmetros (Query, Path, Body implícito via Pydantic). Retorno costuma ser inferido por `response_model`; anotações explícitas de retorno (ex.: `-> TokenResponse`) são opcionais mas ajudam em refactors.
- Evitar `Any` sem necessidade; preferir `TypeVar` ou tipos genéricos em helpers reutilizáveis quando fizer sentido.

---

## 3. Linter e formatter aplicados?

### Estado atual

| Ferramenta   | Uso                          | Onde |
|-------------|------------------------------|------|
| **Ruff**    | Lint (`ruff check`)          | CI (job `lint`), `pyproject.toml` (target-version, line-length) |
| **Formatter** | Não configurado            | —    |
| **Pre-commit** | Não configurado          | —    |
| **mypy**    | Não usado                    | —    |

### O que foi feito / recomendado

1. **Ruff**
   - CI já roda `ruff check app/ tests/`.
   - Em `pyproject.toml`: definidos `target-version = "py312"` e `line-length = 120`; adicionadas regras recomendadas (F, E, W, I, B, C4, UP) e exclusões (migrations, `__init__.py`).
   - Ruff incluído em `requirements-test.txt` para garantir mesma versão no CI e localmente.

2. **Formatter**
   - Ruff format habilitado em `pyproject.toml` (compatível com Black).
   - CI: passo “Format check” com `ruff format --check app/ tests/` para garantir código formatado.

3. **Uso local (recomendado)**
   - Instalar deps de teste: `pip install -r requirements-test.txt`
   - Format: `ruff format app/ tests/` (aplica formatação)
   - Lint: `ruff check app/ tests/`
   - Corrigir automaticamente o que Ruff puder: `ruff check --fix app/ tests/`
   - Antes de abrir PR: rodar lint + format check para evitar falha no CI.

4. **Opcional (futuro)**
   - Pre-commit: hooks para `ruff check` e `ruff format` antes do commit.
   - mypy: para checagem de tipos mais rígida em módulos críticos.

---

## Checklist rápido

- [x] FastAPI: rotas async, Depends, Pydantic, response_model.
- [x] Exceções de domínio centralizadas e mapeadas para HTTP.
- [x] Services com tipagem explícita (parâmetros e retorno).
- [x] Config e schemas tipados.
- [x] Ruff configurado no projeto e no CI.
- [x] Formatter (Ruff format) configurado e verificado no CI.
- [ ] (Opcional) Pre-commit com ruff.
- [ ] (Opcional) mypy em módulos críticos.

---

## Referências

- [FastAPI – Best practices](https://fastapi.tiangolo.com/tutorial/best-practices/)
- [Ruff – Rules](https://docs.astral.sh/ruff/rules/)
- [Pydantic – Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
