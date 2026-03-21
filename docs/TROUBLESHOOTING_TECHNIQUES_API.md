# Erro: `from_position_id` / `to_position_id` ao criar técnica

## Sintoma

Ao salvar uma técnica no app (Flutter), aparece validação da API pedindo:

- `from_position_id` — Field required  
- `to_position_id` — Field required  

## Causa

O **código atual** do repositório **não** usa mais posições em técnicas (`TechniqueCreate` só tem `academy_id`, `name`, `slug`, `description`, `video_url`, `base_points`).  
Se a API ainda exige esses campos, o processo em execução (Docker, outro terminal com `uvicorn`, etc.) está rodando uma **versão antiga** do backend ou o banco não recebeu a migração que remove as colunas.

## O que fazer

1. **Atualizar a API** com o código deste repositório.
2. **Aplicar migrações** (na subida normal da API elas rodam via `run_migrations`; garanta que `migrations/044_remove_technique_positions.sql` foi aplicada).

### Docker (recomendado)

```bash
cd /caminho/AppBaby
docker compose build --no-cache api
docker compose up -d postgres api
```

Confira `GET http://localhost:8000/docs` → `POST /techniques` → o body não deve listar `from_position_id` / `to_position_id`.

### API local (uvicorn)

```bash
# Com Postgres atualizado e .env apontando para ele
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Referência

- Migração: `migrations/044_remove_technique_positions.sql`
- Schema: `app/schemas/technique.py` (`TechniqueCreate`)

O app Flutter foi ajustado para mostrar uma mensagem em português quando detectar esse erro de API antiga.
