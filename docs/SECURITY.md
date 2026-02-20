# Políticas de Segurança

Este documento descreve as políticas e práticas recomendadas de segurança implementadas no projeto.

## Índice

1. [Secrets e Variáveis de Ambiente](#secrets-e-variáveis-de-ambiente)
2. [Autenticação e Autorização](#autenticação-e-autorização)
3. [Validação de Inputs](#validação-de-inputs)
4. [Proteção contra Vulnerabilidades](#proteção-contra-vulnerabilidades)
5. [Logging e Auditoria](#logging-e-auditoria)
6. [Configuração de Produção](#configuração-de-produção)

---

## Secrets e Variáveis de Ambiente

### JWT_SECRET

- **Obrigatório em produção**: O `JWT_SECRET` não pode usar o valor padrão em produção.
- **Força mínima**: O secret deve ter pelo menos 32 caracteres.
- **Geração**: Use um gerador de secrets forte (ex: `openssl rand -hex 32`).
- **Armazenamento**: Nunca commite secrets no controle de versão. Use variáveis de ambiente ou um gerenciador de secrets.

**Exemplo de configuração:**
```bash
# .env (não commitar)
JWT_SECRET=seu-secret-forte-de-pelo-menos-32-caracteres-aqui
ENVIRONMENT=production
```

### Validação Automática

O sistema valida automaticamente:
- Se `JWT_SECRET` está usando o valor padrão em produção (bloqueia inicialização)
- Se `JWT_SECRET` tem pelo menos 32 caracteres
- Se `CORS_ORIGINS` contém `["*"]` em produção (bloqueia inicialização)

---

## Autenticação e Autorização

### JWT (JSON Web Tokens)

- **Expiração**: Tokens expiram em 2 horas (reduzido de 7 dias para maior segurança).
- **Algoritmo**: HS256 (HMAC-SHA256).
- **Uso**: Enviar no header `Authorization: Bearer <token>`.

### Roles e Permissões

O sistema implementa controle de acesso baseado em roles:

- **administrador**: Acesso total ao sistema
- **gerente_academia**: Acesso a recursos da própria academia
- **professor**: Acesso a recursos da própria academia
- **supervisor**: Acesso apenas de leitura
- **aluno**: Acesso limitado aos próprios recursos

### Verificação de Acesso por Academia

Todas as rotas que acessam recursos por academia verificam automaticamente:
- Administradores têm acesso total
- Não-admins só podem acessar recursos da sua própria academia (`current_user.academy_id == resource_academy_id`)

**Helper implementado:** `verify_academy_access()` em `app/core/role_deps.py`

### Rotas Protegidas

Todas as rotas que modificam ou acessam dados sensíveis exigem autenticação:
- `/users/{user_id}/points` - Requer autenticação
- `/users/{user_id}/points_log` - Requer autenticação
- `/techniques` (POST) - Requer autenticação e verificação de academia
- `/lessons/{lesson_id}` - Requer autenticação e verificação de academia
- `/trophies` (todas as rotas) - Requer autenticação e verificação de academia

---

## Validação de Inputs

### Email

- **Validação**: Usa `EmailStr` do Pydantic para validação de formato.
- **Aplicado em**: `LoginRequest`, `UserCreate`, `UserUpdate`, `ProfessorCreate`, `ProfessorUpdate`

### Senhas

- **Comprimento mínimo**: 12 caracteres (aumentado de 6)
- **Comprimento máximo**: 128 caracteres (previne DoS)
- **Validação**: Implementada em `app/schemas/user.py`

**Recomendações para usuários:**
- Use senhas únicas e complexas
- Não reutilize senhas entre serviços
- Considere usar um gerenciador de senhas

### Sanitização de Dados

- **HTML**: Dados inseridos em HTML são escapados usando `escapeHtml()` para prevenir XSS.
- **Aplicado em**: `app/routes/missions.py`, `app/routes/admin.py`

---

## Proteção contra Vulnerabilidades

### XSS (Cross-Site Scripting)

- **Prevenção**: Função `escapeHtml()` implementada em rotas que geram HTML.
- **Aplicado em**: Formulários HTML em `missions.py` e `admin.py`

### Exposição de Erros

- **Produção**: Mensagens de erro genéricas ("Erro interno do servidor") em produção.
- **Desenvolvimento**: Detalhes completos de erro para facilitar debug.
- **Health Check**: Não expõe detalhes de erro de conexão ao banco em produção.

**Implementação:** `app/main.py`, `app/routes/health.py`

### CORS (Cross-Origin Resource Sharing)

- **Desenvolvimento**: Permite `["*"]` por padrão.
- **Produção**: `["*"]` é bloqueado automaticamente. Configure origens específicas:
  ```bash
  CORS_ORIGINS=["https://app.exemplo.com","https://admin.exemplo.com"]
  ```

### SQL Injection

- **Prevenção**: Uso de SQLAlchemy ORM com prepared statements.
- **Validação**: F-strings em queries são evitadas; quando necessárias, são validadas como constantes internas.

---

## Logging e Auditoria

### Admin Impersonation

Todas as tentativas de impersonation por administradores são registradas:

- **Log de sucesso**: Registra admin_id, admin_email, target_user_id, target_user_email
- **Log de falha**: Registra tentativas de impersonation com usuário inválido
- **Nível**: WARNING (para facilitar monitoramento)

**Implementação:** `app/core/auth_deps.py`

**Exemplo de log:**
```
WARNING: Admin impersonation: admin_id=... (email=admin@exemplo.com) impersonating user_id=... (email=user@exemplo.com)
```

### Logs de Segurança

- Exceções não tratadas são registradas com stack trace completo
- Tentativas de acesso não autorizado são registradas
- Falhas de autenticação são registradas

---

## Configuração de Produção

### Checklist de Segurança

Antes de fazer deploy em produção, verifique:

- [ ] `JWT_SECRET` configurado com valor forte (≥32 caracteres)
- [ ] `ENVIRONMENT=production` definido
- [ ] `CORS_ORIGINS` configurado com origens específicas (não `["*"]`)
- [ ] `DATABASE_URL` usando credenciais fortes
- [ ] Logs configurados e monitorados
- [ ] HTTPS habilitado (via proxy reverso/load balancer)
- [ ] Rate limiting configurado adequadamente
- [ ] Backups do banco de dados configurados

### Variáveis de Ambiente Obrigatórias

```bash
# Obrigatórias em produção
JWT_SECRET=<secret-forte-de-pelo-menos-32-caracteres>
ENVIRONMENT=production
DATABASE_URL=postgresql://user:password@host:port/database

# Recomendadas
CORS_ORIGINS=["https://app.exemplo.com"]
LOG_LEVEL=INFO
SEED_ON_STARTUP=false
```

### Rate Limiting

- **Login**: Limitado a 5 tentativas por minuto (configurável via `LOGIN_RATE_LIMIT`)
- **Implementação**: `slowapi` middleware

---

## Práticas Recomendadas

### Para Desenvolvedores

1. **Nunca commite secrets**: Use `.env` e adicione ao `.gitignore`
2. **Valide todos os inputs**: Use schemas Pydantic
3. **Use prepared statements**: Nunca construa queries SQL com f-strings de dados do usuário
4. **Escape dados HTML**: Sempre use `escapeHtml()` ao inserir dados em HTML
5. **Verifique acesso**: Use `verify_academy_access()` para recursos por academia
6. **Teste autenticação**: Garanta que rotas sensíveis exigem autenticação

### Para Administradores

1. **Monitore logs**: Configure alertas para eventos de segurança
2. **Rotacione secrets**: Mude `JWT_SECRET` periodicamente (requer logout de todos os usuários)
3. **Audite impersonation**: Revise logs de impersonation regularmente
4. **Mantenha dependências atualizadas**: Execute `pip list --outdated` regularmente
5. **Use HTTPS**: Configure SSL/TLS em produção

---

## Referências

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [Pydantic Validation](https://docs.pydantic.dev/latest/concepts/validators/)

---

## Contato

Para questões de segurança, entre em contato com a equipe de desenvolvimento.
