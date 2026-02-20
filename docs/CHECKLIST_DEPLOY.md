# Checklist de Deploy - Pré-Produção

Use este checklist antes de fazer deploy em produção. Marque cada item conforme for completando.

---

## 🔴 Crítico (Bloqueia Deploy)

### Secrets e Segurança

- [ ] `JWT_SECRET` configurado com valor forte (32+ caracteres)
- [ ] `POSTGRES_PASSWORD` configurado
- [ ] `.env` **NÃO** está commitado no git
- [ ] Secrets vêm de variáveis de ambiente do servidor/container (não hardcoded)
- [ ] `ENVIRONMENT=production` configurado
- [ ] `CORS_ORIGINS` configurado com origens específicas (não `["*"]`)

### Código

- [ ] `ruff format app/ tests/` executado e commitado
- [ ] `ruff check app/ tests/` sem erros
- [ ] CI passa em todos os jobs (test, lint, format check)

### Banco de Dados

- [ ] Migrations aplicadas
- [ ] Backup automático configurado
- [ ] Credenciais de produção diferentes de desenvolvimento

---

## 🟡 Importante (Recomendado antes do Deploy)

### Configuração

- [ ] `LOG_LEVEL=INFO` ou `WARNING` em produção
- [ ] `LOG_FORMAT=json` configurado (facilita parsing)
- [ ] `SEED_ON_STARTUP=false` em produção
- [ ] `SENTRY_DSN` configurado (se usar Sentry)
- [ ] `ENABLE_METRICS=true`

### Infraestrutura

- [ ] Dockerfile buildado e testado localmente
- [ ] Health checks funcionando (`/health`, `/health/db`)
- [ ] HTTPS configurado (certificado SSL)
- [ ] Firewall configurado

### Monitoramento

- [ ] Prometheus configurado para scraping `/metrics/prometheus`
- [ ] Alertas básicos configurados (erros, latência)
- [ ] Logs sendo coletados (CloudWatch, ELK, etc.)

---

## 🟢 Validação (Testar após Deploy)

### Smoke Tests

- [ ] `GET /health` retorna `200 OK`
- [ ] `GET /health/db` retorna `200 OK` com `database: "connected"`
- [ ] `POST /auth/login` funciona com credenciais válidas
- [ ] `GET /auth/me` funciona com token válido
- [ ] `GET /metrics/prometheus` retorna métricas

### Funcionalidades Críticas

- [ ] Login funciona
- [ ] Criação de usuário funciona (se aplicável)
- [ ] Listagem de recursos funciona
- [ ] Criação de recursos funciona
- [ ] Autenticação obrigatória em rotas protegidas

---

## 📝 Documentação

- [ ] README.md atualizado com instruções de deploy
- [ ] `.env.example` completo e atualizado
- [ ] Documentação de API acessível (`/docs`)
- [ ] Plano de rollback documentado

---

## 🔄 Após Deploy

- [ ] Monitorar logs por 24h
- [ ] Verificar métricas de performance
- [ ] Verificar uso de memória e CPU
- [ ] Verificar latência de requisições
- [ ] Documentar problemas encontrados

---

## ⚠️ Rollback Plan

Se algo der errado:

1. [ ] Reverter para versão anterior do código
2. [ ] Reverter migrations (se necessário): `alembic downgrade -1`
3. [ ] Restaurar backup do banco (se necessário)
4. [ ] Verificar logs para identificar causa

---

**Data do Deploy**: _______________

**Responsável**: _______________

**Observações**:

________________________________________________________
________________________________________________________
________________________________________________________
