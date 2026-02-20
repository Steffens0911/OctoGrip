# Formatação de Código

Este projeto usa **Ruff** para linting e formatação de código Python.

## Configuração

A configuração do Ruff está em `pyproject.toml`:

- **Linter**: Regras E, W, F, I, B, C4, UP
- **Formatter**: Compatível com Black (quote-style: double, line-length: 120)
- **Exclusões**: migrations, `.git`, `__pycache__`, `*.pyc`

## Comandos

### Instalar dependências

```bash
pip install -r requirements-test.txt
```

### Formatar código

```bash
# Formatar todos os arquivos Python em app/ e tests/
ruff format app/ tests/

# Verificar formatação sem alterar arquivos
ruff format --check app/ tests/
```

### Lint (verificar problemas)

```bash
# Verificar problemas
ruff check app/ tests/

# Corrigir automaticamente o que for possível
ruff check --fix app/ tests/
```

## CI/CD

O GitHub Actions roda automaticamente:

1. **Lint**: `ruff check app/ tests/`
2. **Format check**: `ruff format --check app/ tests/`

Se o format check falhar, rode `ruff format app/ tests/` localmente e faça commit.

## Antes de abrir PR

```bash
# 1. Formatar código
ruff format app/ tests/

# 2. Verificar lint e corrigir automaticamente
ruff check --fix app/ tests/

# 3. Se ainda houver problemas, corrigir manualmente
ruff check app/ tests/
```

## Integração com IDE

### VS Code

Adicione ao `.vscode/settings.json`:

```json
{
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll": "explicit",
      "source.organizeImports": "explicit"
    }
  }
}
```

### PyCharm

Configure Ruff como ferramenta externa ou use o plugin Ruff.
