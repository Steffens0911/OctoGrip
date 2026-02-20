# Auditoria de Segurança Ofensiva - Penetration Test

**Data**: 2026-02-20  
**Metodologia**: OWASP Top 10, CWE Top 25  
**Perspectiva**: Atacante externo tentando explorar vulnerabilidades

---

## 🎯 Objetivo do Ataque

Como atacante, meu objetivo é:
1. Obter acesso não autorizado ao sistema
2. Escalar privilégios (tornar-me admin ou acessar dados de outras academias)
3. Extrair dados sensíveis (emails, senhas, tokens)
4. Comprometer a integridade dos dados
5. Negar serviço (DoS)

---

## 🔍 Fase 1: Reconhecimento e Enumeração

### 1.1 Descoberta de Endpoints

**Técnica**: Enumeração de rotas públicas

**Vetores de Ataque**:
- ✅ `/docs` - Swagger UI exposto (padrão FastAPI)
- ✅ `/health` - Health check exposto
- ✅ `/health/db` - Health check do banco (pode expor informações)
- ✅ `/metrics/prometheus` - Métricas expostas (se habilitado)

**Risco**: 🟡 **MÉDIO**
- Swagger UI expõe toda a estrutura da API
- Health checks podem revelar versões e status do sistema
- Métricas podem expor informações sobre uso e performance

**Recomendação**: 
- Desabilitar `/docs` em produção ou proteger com autenticação
- Considerar rate limiting em health checks
- Verificar se métricas não expõem dados sensíveis

---

### 1.2 Informações Expostas em Erros

**Técnica**: Análise de mensagens de erro

**Vetores de Ataque**:
- Tentar login com email inválido → Mensagem genérica ✅ (bom)
- Tentar acessar recurso inexistente → `404 Not Found` ✅ (bom)
- Forçar erro interno → Em desenvolvimento expõe stack trace ⚠️

**Código analisado** (`app/main.py`):
```python
if _IS_PRODUCTION:
    detail = "Erro interno do servidor."  # ✅ Bom
else:
    detail = str(exc) or "Erro interno do servidor."  # ⚠️ Risco em dev
```

**Risco**: 🟡 **MÉDIO** (apenas em desenvolvimento)
- Stack traces podem revelar estrutura de código, paths, versões de bibliotecas

**Recomendação**: ✅ Já implementado corretamente (só expõe detalhes em dev)

---

## 🔐 Fase 2: Autenticação e Autorização

### 2.1 Ataque de Força Bruta no Login

**Técnica**: Tentativas múltiplas de login

**Vetor de Ataque**:
```bash
# Tentar múltiplos logins com senhas comuns
for password in $(cat wordlist.txt); do
  curl -X POST http://api/login \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@example.com","password":"'$password'"}'
done
```

**Proteção encontrada**:
- ✅ Rate limiting implementado: `@limiter.limit(settings.LOGIN_RATE_LIMIT)` (padrão: 5/minuto)
- ✅ Mensagem genérica: "E-mail ou senha inválidos" (não revela se email existe)

**Risco**: 🟢 **BAIXO** (proteção adequada)

**Melhoria sugerida**:
- Considerar lockout de conta após N tentativas falhas
- Implementar CAPTCHA após X tentativas

---

### 2.2 JWT Token Manipulation

**Técnica**: Análise e manipulação de tokens JWT

**Vetores de Ataque**:
1. **Decodificar token sem verificar assinatura**:
   ```python
   # Token JWT tem formato: header.payload.signature
   # Payload pode ser decodificado sem secret (base64)
   import jwt
   token = "eyJ..."
   decoded = jwt.decode(token, options={"verify_signature": False})
   # Pode revelar: user_id, exp (expiração)
   ```

2. **Tentar usar algoritmo "none"**:
   ```python
   # Tentar criar token sem assinatura
   payload = {"sub": "admin-user-id", "exp": future_timestamp}
   token = jwt.encode(payload, "", algorithm="none")
   ```

**Proteção encontrada** (`app/core/security.py`):
```python
payload = jwt.decode(
    token,
    settings.JWT_SECRET,
    algorithms=[settings.JWT_ALGORITHM],  # ✅ Especifica algoritmo
)
```

**Risco**: 🟢 **BAIXO** (implementação correta)
- Algoritmo especificado explicitamente (previne "none")
- Secret obrigatório para decodificação

**Melhoria sugerida**:
- Verificar se `JWT_SECRET` é forte (já implementado ✅)
- Considerar refresh tokens para reduzir janela de ataque

---

### 2.3 Admin Impersonation Attack

**Técnica**: Explorar funcionalidade de impersonation

**Vetor de Ataque**:
```bash
# Se conseguir token de admin, tentar impersonar outros usuários
curl -X GET http://api/users/{target_user_id} \
  -H "Authorization: Bearer <admin_token>" \
  -H "X-Impersonate-User: <target_user_id>"
```

**Código analisado** (`app/core/auth_deps.py`):
```python
impersonate_header = request.headers.get("X-Impersonate-User")
if impersonate_header and real_user.role == "administrador":
    target_id = UUID(impersonate_header.strip())
    target_user = await get_user(db, target_id)
    if target_user:
        # ✅ Log de auditoria implementado
        logger.warning("Admin impersonation: ...")
        return target_user
```

**Risco**: 🟡 **MÉDIO**
- ✅ Logging de auditoria implementado
- ⚠️ Não há limite de tempo para impersonation
- ⚠️ Não há notificação ao usuário sendo impersonado

**Melhoria sugerida**:
- Adicionar timestamp de expiração para impersonation
- Notificar usuário quando está sendo impersonado
- Adicionar confirmação adicional (ex: 2FA) para impersonation

---

### 2.4 Authorization Bypass - IDOR (Insecure Direct Object Reference)

**Técnica**: Tentar acessar recursos de outras academias

**Vetores de Ataque**:
1. **Acessar usuário de outra academia**:
   ```bash
   # Como professor da academia A, tentar acessar usuário da academia B
   curl -X GET http://api/users/{user_id_academy_b} \
     -H "Authorization: Bearer <professor_token_academy_a>"
   ```

2. **Acessar missão de outra academia**:
   ```bash
   curl -X GET http://api/missions/{mission_id_academy_b} \
     -H "Authorization: Bearer <professor_token_academy_a>"
   ```

**Proteção encontrada** (`app/routes/users.py`, `app/routes/missions.py`):
```python
# ✅ Verificação implementada
if current_user.role != "administrador" and user.academy_id != current_user.academy_id:
    raise HTTPException(status_code=403, detail="Acesso negado...")
```

**Risco**: 🟢 **BAIXO** (proteção adequada)
- Verificação de `academy_id` implementada em rotas críticas

**Verificação necessária**:
- Revisar TODAS as rotas que acessam recursos por ID para garantir verificação

---

## 💉 Fase 3: Injection Attacks

### 3.1 SQL Injection

**Técnica**: Tentar injetar SQL em parâmetros

**Vetores de Ataque**:
```bash
# Tentar SQL injection em parâmetros de query
curl "http://api/users?academy_id=' OR '1'='1"
curl "http://api/missions?limit=10; DROP TABLE users;--"
```

**Proteção encontrada**:
- ✅ SQLAlchemy ORM usado (previne SQL injection)
- ✅ Parâmetros tipados (UUID, int)
- ✅ Queries parametrizadas: `select(User).where(User.id == user_id)`

**Código analisado** (`app/run_migrations.py`):
```python
# ⚠️ F-string em query de tracking (mas é constante interna)
rows = conn.execute(text(f"SELECT filename FROM {_TRACKING_TABLE}")).fetchall()
```

**Risco**: 🟢 **BAIXO**
- ORM previne SQL injection
- F-string em migrations usa constante interna (seguro)

**Recomendação**: ✅ Código seguro, manter uso de ORM

---

### 3.2 NoSQL Injection

**Risco**: 🟢 **N/A** (PostgreSQL usado, não NoSQL)

---

### 3.3 Command Injection

**Técnica**: Tentar executar comandos do sistema

**Vetores de Ataque**:
- Tentar injetar comandos em parâmetros que são passados para shell
- Analisar uso de `os.system()`, `subprocess.call()`, etc.

**Análise**: Não encontrado uso direto de comandos shell no código analisado

**Risco**: 🟢 **BAIXO**

---

### 3.4 LDAP Injection

**Risco**: 🟢 **N/A** (não usa LDAP)

---

## 🌐 Fase 4: Cross-Site Scripting (XSS)

### 4.1 Stored XSS

**Técnica**: Injetar JavaScript em campos de entrada

**Vetores de Ataque**:
```javascript
// Tentar injetar script em campos de texto
{
  "name": "<script>alert('XSS')</script>",
  "email": "test@example.com"
}

// Tentar injetar em descrições
{
  "description": "<img src=x onerror=alert('XSS')>"
}
```

**Proteção encontrada** (`app/routes/admin.py`, `app/routes/missions.py`):
```javascript
function escapeHtml(s) {
  const div = document.createElement('div');
  div.textContent = s;
  return div.innerHTML;
}
// ✅ Usado ao inserir dados em HTML
tbody.innerHTML = list.map(a => '<td>' + escapeHtml(a.name) + '</td>')
```

**Risco**: 🟡 **MÉDIO**
- ✅ Escape implementado em painéis HTML
- ⚠️ Verificar se TODOS os lugares que inserem dados do usuário em HTML usam escape

**Recomendação**:
- Auditar todos os templates HTML
- Considerar usar framework que escapa automaticamente (ex: React, Vue)

---

### 4.2 Reflected XSS

**Técnica**: Refletir input do usuário na resposta

**Vetores de Ataque**:
```bash
# Tentar refletir parâmetros na resposta
curl "http://api/search?q=<script>alert('XSS')</script>"
```

**Análise**: Não encontrados endpoints que refletem input diretamente em HTML

**Risco**: 🟢 **BAIXO**

---

## 🔓 Fase 5: Broken Access Control

### 5.1 Missing Function Level Access Control

**Técnica**: Tentar acessar funções administrativas sem ser admin

**Vetores de Ataque**:
```bash
# Tentar acessar painel admin sem ser admin
curl -X GET http://api/admin \
  -H "Authorization: Bearer <aluno_token>"

# Tentar criar academia sem ser admin
curl -X POST http://api/academies \
  -H "Authorization: Bearer <professor_token>"
```

**Proteção encontrada**:
- ✅ `require_admin()` usado em rotas administrativas
- ✅ `require_write_access()` usado em rotas de escrita

**Risco**: 🟢 **BAIXO** (proteção adequada)

---

### 5.2 Mass Assignment

**Técnica**: Tentar definir campos não permitidos no body da requisição

**Vetores de Ataque**:
```json
// Tentar definir role como admin ao criar usuário
{
  "email": "attacker@example.com",
  "name": "Attacker",
  "role": "administrador"  // ⚠️ Tentar escalar privilégios
}
```

**Proteção encontrada** (`app/schemas/user.py`):
- Schemas Pydantic definem campos permitidos
- Campos não definidos no schema são ignorados (se `extra="forbid"`)

**Risco**: 🟡 **MÉDIO**
- Verificar se schemas usam `extra="forbid"` ou `extra="ignore"`
- Garantir que campos sensíveis (role, academy_id) não podem ser definidos por usuários não-admin

**Recomendação**:
- Revisar todos os schemas de criação/atualização
- Garantir que campos administrativos sejam removidos antes de salvar

---

### 5.3 CORS Misconfiguration

**Técnica**: Explorar configuração CORS

**Vetor de Ataque**:
```javascript
// Tentar fazer requisição cross-origin
fetch('http://api/users', {
  method: 'GET',
  headers: {
    'Authorization': 'Bearer <token>',
    'Origin': 'https://evil.com'
  }
})
```

**Proteção encontrada** (`app/config.py`):
```python
CORS_ORIGINS: List[str] = ["*"]  # ⚠️ Permite qualquer origem por padrão
# ✅ Validação: bloqueia ["*"] em produção
```

**Risco**: 🟡 **MÉDIO** (apenas se mal configurado)
- ✅ Validação impede `["*"]` em produção
- ⚠️ Se configurado incorretamente, permite qualquer origem

**Recomendação**: ✅ Já protegido com validação

---

## 🔑 Fase 6: Security Misconfiguration

### 6.1 Exposição de Secrets

**Técnica**: Buscar secrets em código, logs, variáveis de ambiente

**Vetores de Ataque**:
1. **Verificar código fonte** (se público):
   - Buscar por `JWT_SECRET`, `POSTGRES_PASSWORD` hardcoded
   - Verificar `.env` commitado no git

2. **Verificar logs**:
   - Logs podem conter tokens, senhas, secrets

3. **Verificar headers HTTP**:
   - Headers podem expor versões, tecnologias

**Proteção encontrada**:
- ✅ Secrets não hardcoded (usam variáveis de ambiente)
- ✅ `.env` no `.gitignore`
- ✅ Logs sanitizam parâmetros sensíveis (`_sanitize_params`)

**Risco**: 🟡 **MÉDIO**
- Depende de configuração correta em produção

**Recomendação**:
- Garantir que `.env` nunca seja commitado
- Usar secrets management em produção
- Revisar logs para garantir que não expõem dados sensíveis

---

### 6.2 Informações Expostas em Headers

**Técnica**: Analisar headers HTTP

**Vetores de Ataque**:
```bash
curl -I http://api/health
# Verificar headers como:
# - Server: uvicorn/0.32.1 (pode revelar versão)
# - X-Powered-By: ...
```

**Risco**: 🟡 **BAIXO-MÉDIO**
- Headers podem revelar tecnologias e versões

**Recomendação**:
- Configurar uvicorn para não expor versão
- Remover headers desnecessários

---

### 6.3 Debug Mode em Produção

**Técnica**: Verificar se modo debug está habilitado

**Vetor de Ataque**:
- Tentar acessar `/debug` ou endpoints de debug
- Verificar se stack traces são expostos

**Análise**: Não encontrado modo debug explícito

**Risco**: 🟢 **BAIXO**

---

## 📊 Fase 7: Sensitive Data Exposure

### 7.1 Exposição de Senhas

**Técnica**: Tentar extrair senhas em texto plano

**Vetores de Ataque**:
1. **Verificar se senhas são retornadas em respostas**:
   ```bash
   curl -X GET http://api/users/{id} \
     -H "Authorization: Bearer <token>"
   # Verificar se password_hash ou password está na resposta
   ```

2. **Verificar logs**:
   - Logs podem conter senhas se não sanitizados

**Proteção encontrada**:
- ✅ Senhas armazenadas como hash (`password_hash`)
- ✅ Schemas não incluem `password` ou `password_hash` em respostas
- ✅ Logs sanitizam parâmetros com "password" no nome

**Risco**: 🟢 **BAIXO** (proteção adequada)

---

### 7.2 Exposição de Tokens

**Técnica**: Tentar extrair tokens JWT

**Vetores de Ataque**:
1. **Verificar se tokens são logados**
2. **Verificar se tokens aparecem em URLs** (query params)
3. **Verificar se tokens são expostos em erros**

**Proteção encontrada**:
- ✅ Tokens enviados apenas em header `Authorization`
- ✅ Logs sanitizam "token" e "authorization"

**Risco**: 🟢 **BAIXO**

---

### 7.3 Information Disclosure em Health Checks

**Técnica**: Analisar informações expostas em health checks

**Vetor de Ataque**:
```bash
curl http://api/health/db
# Pode expor:
# - Versão do PostgreSQL
# - Status de conexão
# - Detalhes de erro (em dev)
```

**Código analisado** (`app/routes/health.py`):
```python
if _IS_PRODUCTION:
    return {"status": "error", "database": "disconnected"}  # ✅ Genérico
else:
    return {"status": "error", "database": str(e)}  # ⚠️ Expõe detalhes em dev
```

**Risco**: 🟡 **MÉDIO** (apenas em desenvolvimento)
- ✅ Produção não expõe detalhes

---

## 🚫 Fase 8: Denial of Service (DoS)

### 8.1 Rate Limiting Insuficiente

**Técnica**: Enviar muitas requisições para sobrecarregar o servidor

**Vetores de Ataque**:
```bash
# Enviar 1000 requisições simultâneas
for i in {1..1000}; do
  curl http://api/users &
done
```

**Proteção encontrada**:
- ✅ Rate limiting no login (`5/minute`)
- ⚠️ Rate limiting não configurado globalmente
- ⚠️ Não há rate limiting por IP em outras rotas

**Risco**: 🟡 **MÉDIO**
- Apenas login tem rate limiting
- Outras rotas podem ser sobrecarregadas

**Recomendação**:
- Adicionar rate limiting global
- Configurar rate limiting por IP em rotas críticas
- Considerar usar WAF ou proxy reverso com rate limiting

---

### 8.2 Resource Exhaustion

**Técnica**: Consumir recursos do servidor

**Vetores de Ataque**:
1. **Queries pesadas**:
   ```bash
   # Tentar fazer query sem limite
   curl "http://api/users?limit=999999"
   ```

2. **Upload de arquivos grandes** (se houver endpoint de upload)

**Proteção encontrada**:
- ✅ Paginação implementada com limite máximo (`limit=200` em users)
- ✅ Queries usam `offset` e `limit`

**Risco**: 🟢 **BAIXO** (proteção adequada)

---

### 8.3 Database Connection Pool Exhaustion

**Técnica**: Abrir muitas conexões simultâneas

**Vetor de Ataque**:
- Abrir muitas requisições simultâneas que abrem conexões DB
- Pool pode esgotar e negar novas conexões

**Proteção encontrada** (`app/config.py`):
```python
DB_POOL_SIZE: int = 20
DB_MAX_OVERFLOW: int = 30
```

**Risco**: 🟡 **MÉDIO**
- Pool limitado pode ser esgotado sob carga alta

**Recomendação**:
- Monitorar uso do pool
- Ajustar tamanho conforme carga esperada
- Implementar timeout adequado

---

## 🔄 Fase 9: CSRF (Cross-Site Request Forgery)

### 9.1 CSRF em Formulários HTML

**Técnica**: Explorar falta de proteção CSRF

**Vetor de Ataque**:
```html
<!-- Site malicioso tenta fazer requisição em nome do usuário -->
<form action="http://api/academies" method="POST">
  <input name="name" value="Academia Maliciosa">
</form>
<script>document.forms[0].submit();</script>
```

**Proteção encontrada** (`app/routes/admin.py`, `app/routes/missions.py`):
- ✅ CSRF token implementado (`generate_csrf_token`)
- ✅ Token enviado em header `X-CSRF-Token`
- ⚠️ Verificação de CSRF não encontrada em todas as rotas POST/PUT/DELETE

**Risco**: 🟡 **MÉDIO**
- CSRF token gerado, mas verificação pode não estar implementada em todas as rotas

**Recomendação**:
- Verificar se todas as rotas que modificam dados validam CSRF token
- Considerar usar SameSite cookies se cookies forem introduzidos

---

## 📝 Fase 10: Logging and Monitoring Failures

### 10.1 Falta de Logging de Tentativas de Ataque

**Técnica**: Verificar se tentativas de ataque são logadas

**Análise**:
- ✅ Logs de impersonation implementados
- ✅ Logs de erros implementados
- ⚠️ Tentativas de login falhadas podem não ser logadas adequadamente

**Risco**: 🟡 **BAIXO-MÉDIO**
- Logs existem, mas podem não capturar todos os eventos de segurança

**Recomendação**:
- Logar tentativas de login falhadas
- Logar tentativas de acesso não autorizado
- Configurar alertas para padrões suspeitos

---

## 🎯 Resumo de Vulnerabilidades Encontradas

### 🔴 Críticas (0 encontradas)

Nenhuma vulnerabilidade crítica encontrada. ✅

---

### 🟡 Médias (8 encontradas)

1. **Swagger UI Exposto** (`/docs`)
   - **Risco**: Expõe estrutura completa da API
   - **Mitigação**: Desabilitar em produção ou proteger com autenticação

2. **Admin Impersonation sem Limite de Tempo**
   - **Risco**: Impersonation pode durar indefinidamente
   - **Mitigação**: Adicionar timestamp de expiração

3. **Rate Limiting Apenas no Login**
   - **Risco**: Outras rotas podem ser sobrecarregadas
   - **Mitigação**: Adicionar rate limiting global

4. **CSRF Token Gerado mas Não Verificado em Todas Rotas**
   - **Risco**: Algumas rotas podem ser vulneráveis a CSRF
   - **Mitigação**: Verificar CSRF em todas rotas que modificam dados

5. **Mass Assignment Potencial**
   - **Risco**: Usuários podem tentar definir campos não permitidos
   - **Mitigação**: Revisar schemas e garantir `extra="forbid"`

6. **Pool de Conexões Limitado**
   - **Risco**: Pool pode esgotar sob carga alta
   - **Mitigação**: Monitorar e ajustar conforme necessário

7. **Headers Expõem Versões**
   - **Risco**: Revela tecnologias e versões
   - **Mitigação**: Configurar para não expor versões

8. **Logs Podem Não Capturar Todos Eventos de Segurança**
   - **Risco**: Tentativas de ataque podem passar despercebidas
   - **Mitigação**: Melhorar logging de eventos de segurança

---

### 🟢 Baixas (Melhorias)

1. Considerar lockout de conta após tentativas falhadas
2. Implementar refresh tokens
3. Adicionar notificação ao usuário sendo impersonado
4. Revisar todos os templates HTML para XSS
5. Configurar WAF ou proxy reverso com rate limiting

---

## 🛡️ Pontos Fortes de Segurança

✅ **Autenticação JWT bem implementada**
- Algoritmo especificado explicitamente
- Secret obrigatório
- Validação de expiração

✅ **Autorização por roles robusta**
- Verificação de `academy_id` implementada
- Roles bem definidas

✅ **Proteção contra SQL Injection**
- ORM usado consistentemente
- Queries parametrizadas

✅ **Rate Limiting no Login**
- Previne força bruta básica

✅ **Sanitização de Logs**
- Parâmetros sensíveis são sanitizados

✅ **Validação de Secrets em Produção**
- Bloqueia valores padrão inseguros

---

## 📋 Plano de Correção Prioritizado

### Prioridade Alta (Corrigir Antes de Produção)

1. ✅ Desabilitar `/docs` em produção ou proteger com autenticação
2. ✅ Adicionar rate limiting global além do login
3. ✅ Verificar e implementar validação CSRF em todas rotas que modificam dados
4. ✅ Revisar schemas para prevenir mass assignment

### Prioridade Média (Corrigir em Próxima Sprint)

1. Adicionar timestamp de expiração para impersonation
2. Configurar headers para não expor versões
3. Melhorar logging de eventos de segurança
4. Monitorar e ajustar pool de conexões

### Prioridade Baixa (Melhorias Contínuas)

1. Implementar lockout de conta
2. Adicionar refresh tokens
3. Configurar WAF
4. Revisar templates HTML para XSS

---

## 🎓 Conclusão

O projeto demonstra **boa segurança geral** com:
- ✅ Autenticação e autorização bem implementadas
- ✅ Proteção contra SQL injection
- ✅ Validações adequadas
- ✅ Logging de auditoria

**Principais áreas de atenção**:
- Rate limiting mais abrangente
- Verificação CSRF completa
- Prevenção de mass assignment
- Exposição de informações (Swagger, headers)

**Score de Segurança**: **7.5/10**

**Recomendação**: ✅ **Pronto para produção** após corrigir itens de prioridade alta.

---

**Metodologia**: Baseada em OWASP Top 10 (2021), CWE Top 25, e práticas de penetration testing.
