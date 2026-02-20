# Correções de Segurança - Guia Prático

Este documento fornece instruções práticas para corrigir as vulnerabilidades identificadas na auditoria ofensiva.

---

## 🔴 Prioridade Alta

### 1. Desabilitar Swagger UI em Produção

**Problema**: `/docs` expõe estrutura completa da API.

**Solução**:

**Opção A - Desabilitar completamente** (`app/main.py`):
```python
from app.config import settings

app = FastAPI(
    title="JJB API",
    description="API do MVP SaaS de ensino de jiu-jitsu para iniciantes",
    version="0.1.0",
    lifespan=lifespan,
    # Desabilitar docs em produção
    docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
    openapi_url="/openapi.json" if settings.ENVIRONMENT != "production" else None,
)
```

**Opção B - Proteger com autenticação**:
```python
from fastapi import Request
from fastapi.security import HTTPBearer

security = HTTPBearer()

@app.get("/docs", include_in_schema=False)
async def get_documentation(request: Request, current_user: User = Depends(require_admin)):
    """Documentação protegida - apenas admins."""
    from fastapi.openapi.docs import get_swagger_ui_html
    return get_swagger_ui_html(openapi_url="/openapi.json", title="API Docs")
```

**Recomendação**: Opção A (mais simples e seguro).

---

### 2. Adicionar Rate Limiting Global

**Problema**: Apenas login tem rate limiting.

**Solução** (`app/core/rate_limit.py`):
```python
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.middleware import SlowAPIMiddleware

# Limiter global
limiter = Limiter(key_func=get_remote_address)

# Adicionar middleware global em main.py
app.add_middleware(SlowAPIMiddleware)
```

**Configurar limites por rota** (`app/routes/users.py`):
```python
@router.get("", response_model=list[UserRead])
@limiter.limit("100/minute")  # 100 requisições por minuto
async def users_list(...):
    ...
```

**Limite global padrão** (`app/main.py`):
```python
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    # Aplicar limite global se não houver limite específico
    if not hasattr(request.state, "rate_limit_applied"):
        # Verificar limite global (ex: 200/minuto por IP)
        ...
    return await call_next(request)
```

**Alternativa mais simples**: Usar middleware de rate limiting do FastAPI ou configurar no proxy reverso (nginx, Cloudflare).

---

### 3. Verificar e Implementar CSRF em Todas Rotas

**Problema**: CSRF token gerado mas verificação pode estar incompleta.

**Solução** - Criar middleware de CSRF (`app/core/csrf.py`):
```python
from fastapi import Request, HTTPException, status
from app.core.security import verify_csrf_token
from app.core.auth_deps import get_current_user_optional

async def verify_csrf_middleware(request: Request, call_next):
    """Middleware que verifica CSRF token em requisições que modificam dados."""
    # Apenas para métodos que modificam dados
    if request.method in ("POST", "PUT", "PATCH", "DELETE"):
        # Obter usuário atual (se autenticado)
        user = await get_current_user_optional(request)
        if user:
            # Verificar CSRF token no header
            csrf_token = request.headers.get("X-CSRF-Token")
            if not csrf_token or not verify_csrf_token(csrf_token, user.id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="CSRF token inválido ou ausente.",
                )
    return await call_next(request)
```

**Aplicar em rotas específicas** (`app/routes/academies.py`):
```python
from app.core.csrf import verify_csrf_middleware

@router.post("", response_model=AcademyRead)
async def academy_create(
    body: AcademyCreate,
    request: Request,  # Adicionar Request
    ...
):
    # Middleware já verificou CSRF
    ...
```

**Verificar rotas que precisam de CSRF**:
- ✅ `/admin` - Já tem CSRF token gerado
- ✅ `/missions/panel` - Já tem CSRF token gerado
- ⚠️ Verificar todas rotas POST/PUT/DELETE que não são APIs REST puras

---

### 4. Prevenir Mass Assignment

**Problema**: Usuários podem tentar definir campos não permitidos.

**Solução** - Revisar schemas (`app/schemas/user.py`):
```python
from pydantic import BaseModel, ConfigDict

class UserCreate(BaseModel):
    email: EmailStr
    name: str | None = None
    academy_id: UUID | None = None
    # ⚠️ NÃO incluir: role, password_hash, points
    
    model_config = ConfigDict(
        extra="forbid"  # ✅ Bloqueia campos não definidos
    )
```

**Remover campos administrativos antes de salvar** (`app/services/user_service.py`):
```python
async def create_user(
    db: AsyncSession,
    email: str,
    name: str | None = None,
    graduation: str | None = None,
    academy_id: UUID | None = None,
    password: str | None = None,
    role: str = "aluno",  # ✅ Definido pelo serviço, não pelo usuário
) -> User:
    # Garantir que role não pode ser definido pelo usuário
    if role not in ("aluno", "professor", "gerente_academia", "supervisor"):
        role = "aluno"  # Default seguro
    
    # Se não-admin tentar criar com role diferente, ignorar
    ...
```

**Verificar todos os schemas**:
- `UserCreate`, `UserUpdate`
- `AcademyCreate`, `AcademyUpdate`
- `MissionCreate`, `MissionUpdate`
- Etc.

---

## 🟡 Prioridade Média

### 5. Adicionar Expiração para Impersonation

**Problema**: Impersonation pode durar indefinidamente.

**Solução** (`app/core/auth_deps.py`):
```python
from datetime import datetime, timedelta

# Adicionar timestamp ao token de impersonation
def create_impersonation_token(user_id: UUID, target_id: UUID) -> str:
    """Cria token de impersonation com expiração de 1 hora."""
    expire = datetime.now(timezone.utc) + timedelta(hours=1)
    return jwt.encode(
        {
            "sub": str(user_id),
            "target": str(target_id),
            "type": "impersonation",
            "exp": expire,
        },
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )

# Verificar expiração ao usar
async def get_current_user(...):
    ...
    impersonate_header = request.headers.get("X-Impersonate-User")
    if impersonate_header and real_user.role == "administrador":
        # Decodificar e verificar token de impersonation
        try:
            token_data = jwt.decode(
                impersonate_header,
                settings.JWT_SECRET,
                algorithms=[settings.JWT_ALGORITHM],
            )
            if token_data.get("type") != "impersonation":
                raise HTTPException(status_code=403, detail="Token inválido")
            target_id = UUID(token_data["target"])
        except JWTError:
            raise HTTPException(status_code=403, detail="Token de impersonation inválido ou expirado")
        ...
```

---

### 6. Configurar Headers para Não Expor Versões

**Problema**: Headers expõem versões de tecnologias.

**Solução** (`app/main.py`):
```python
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    """Adiciona headers de segurança e remove informações sensíveis."""
    response = await call_next(request)
    
    # Remover header Server (se uvicorn adicionar)
    response.headers.pop("server", None)
    
    # Adicionar headers de segurança
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    
    return response
```

**Configurar uvicorn** (`uvicorn` command ou `main.py`):
```python
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        server_header=False,  # ✅ Não expor header Server
        date_header=False,    # Opcional: não expor Date header
    )
```

---

### 7. Melhorar Logging de Eventos de Segurança

**Problema**: Tentativas de ataque podem não ser logadas.

**Solução** (`app/routes/auth.py`):
```python
@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.LOGIN_RATE_LIMIT)
async def login(
    request: Request,
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login com e-mail e senha."""
    user = await get_user_by_email(db, body.email)
    
    if not user or not user.password_hash:
        # ✅ Logar tentativa de login com email inexistente
        logger.warning(
            "Tentativa de login com email inexistente",
            extra={
                "email": body.email,
                "ip": request.client.host,
                "user_agent": request.headers.get("user-agent"),
            },
        )
        raise HTTPException(...)
    
    if not verify_password(body.password, user.password_hash):
        # ✅ Logar tentativa de login com senha incorreta
        logger.warning(
            "Tentativa de login com senha incorreta",
            extra={
                "user_id": str(user.id),
                "email": user.email,
                "ip": request.client.host,
                "user_agent": request.headers.get("user-agent"),
            },
        )
        raise HTTPException(...)
    
    # ✅ Logar login bem-sucedido
    logger.info(
        "Login bem-sucedido",
        extra={
            "user_id": str(user.id),
            "email": user.email,
            "ip": request.client.host,
        },
    )
    ...
```

**Adicionar logging em tentativas de acesso não autorizado** (`app/core/role_deps.py`):
```python
def verify_academy_access(user: User, academy_id: str | None) -> None:
    """Verifica se usuário tem acesso à academia."""
    if user.role == "administrador":
        return
    
    if not academy_id or str(user.academy_id) != academy_id:
        # ✅ Logar tentativa de acesso não autorizado
        logger.warning(
            "Tentativa de acesso não autorizado a academia",
            extra={
                "user_id": str(user.id),
                "user_academy_id": str(user.academy_id),
                "requested_academy_id": academy_id,
            },
        )
        raise HTTPException(...)
```

---

### 8. Monitorar Pool de Conexões

**Problema**: Pool pode esgotar sob carga alta.

**Solução** - Adicionar métricas (`app/core/metrics.py`):
```python
db_pool_size = Gauge(
    "db_pool_size",
    "Tamanho do pool de conexões",
)

db_pool_checked_out = Gauge(
    "db_pool_checked_out",
    "Conexões em uso do pool",
)

db_pool_overflow = Gauge(
    "db_pool_overflow",
    "Conexões de overflow em uso",
)
```

**Atualizar health check** (`app/routes/health.py`):
```python
@router.get("/db")
async def health_db(db: AsyncSession = Depends(get_db)):
    """Health check com métricas do pool."""
    ...
    pool = async_engine.pool
    
    # Atualizar métricas
    db_pool_size.set(pool.size())
    db_pool_checked_out.set(pool.checkedout())
    db_pool_overflow.set(pool.overflow())
    
    # Alertar se pool está quase esgotado
    if pool.checkedout() > pool.size() * 0.8:
        logger.warning(
            "Pool de conexões quase esgotado",
            extra={
                "pool_size": pool.size(),
                "checked_out": pool.checkedout(),
                "overflow": pool.overflow(),
            },
        )
    ...
```

---

## 🟢 Prioridade Baixa (Melhorias)

### 9. Implementar Lockout de Conta

**Solução** (`app/services/user_service.py`):
```python
from datetime import datetime, timedelta

class User(Base):
    ...
    failed_login_attempts: int = 0
    account_locked_until: datetime | None = None

async def check_account_lockout(db: AsyncSession, user: User) -> bool:
    """Verifica se conta está bloqueada."""
    if user.account_locked_until and user.account_locked_until > datetime.now(timezone.utc):
        return True
    return False

async def increment_failed_login(db: AsyncSession, user: User) -> None:
    """Incrementa tentativas falhadas e bloqueia se necessário."""
    user.failed_login_attempts += 1
    
    if user.failed_login_attempts >= 5:
        # Bloquear por 30 minutos
        user.account_locked_until = datetime.now(timezone.utc) + timedelta(minutes=30)
        logger.warning(
            "Conta bloqueada após múltiplas tentativas falhadas",
            extra={"user_id": str(user.id), "email": user.email},
        )
    
    await db.commit()
```

---

### 10. Adicionar Refresh Tokens

**Solução** (`app/core/security.py`):
```python
def create_refresh_token(user_id: UUID) -> str:
    """Cria refresh token (válido por 7 dias)."""
    expire = datetime.now(timezone.utc) + timedelta(days=7)
    return jwt.encode(
        {"sub": str(user_id), "type": "refresh", "exp": expire},
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )

def create_access_token(subject: str | UUID) -> str:
    """Cria access token (válido por 2 horas)."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": str(subject), "type": "access", "exp": expire},
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )
```

**Endpoint de refresh** (`app/routes/auth.py`):
```python
@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    refresh_token: str = Body(...),
    db: AsyncSession = Depends(get_db),
):
    """Renova access token usando refresh token."""
    try:
        payload = jwt.decode(
            refresh_token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Token inválido")
        
        user_id = UUID(payload["sub"])
        user = await get_user(db, user_id)
        if not user:
            raise HTTPException(status_code=401, detail="Usuário não encontrado")
        
        new_access_token = create_access_token(user.id)
        return TokenResponse(access_token=new_access_token)
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido ou expirado")
```

---

## 📋 Checklist de Implementação

### Prioridade Alta

- [x] Desabilitar `/docs` em produção — `docs_url=None`, `redoc_url=None`, `openapi_url=None` quando `_IS_PRODUCTION`
- [x] Adicionar rate limiting global — `default_limits=["200/minute"]` + limites específicos em rotas sensíveis
- [ ] Verificar CSRF em todas rotas POST/PUT/DELETE — CSRF via header pode ser aplicado via proxy reverso
- [x] Revisar schemas e adicionar `extra="forbid"` — Todos os schemas de escrita (Create/Update/Request) protegidos
- [x] Remover campos administrativos antes de salvar — Já existente em user_update (non-admin não altera academy_id)

### Prioridade Média

- [ ] Adicionar expiração para impersonation
- [x] Configurar headers de segurança — `SecurityHeadersMiddleware` com X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy, Permissions-Policy, Cache-Control
- [x] Melhorar logging de eventos de segurança — Login falhado/sucesso, acesso negado, acesso cross-academy com IP e user_id
- [x] Adicionar métricas do pool de conexões — `db_pool_size`, `db_pool_overflow`, `security_events_total` + alertas >80% utilização

### Prioridade Baixa

- [ ] Implementar lockout de conta
- [ ] Adicionar refresh tokens
- [ ] Configurar WAF (se aplicável)
- [ ] Revisar templates HTML para XSS

---

## 🧪 Testes de Validação

Após implementar correções, testar:

1. **Swagger desabilitado**:
   ```bash
   curl http://api/docs  # Deve retornar 404 em produção
   ```

2. **Rate limiting funcionando**:
   ```bash
   # Enviar 200 requisições em 1 minuto
   for i in {1..200}; do curl http://api/users & done
   # Deve bloquear após limite
   ```

3. **CSRF protegido**:
   ```bash
   # Tentar POST sem CSRF token
   curl -X POST http://api/academies -H "Authorization: Bearer <token>"
   # Deve retornar 403
   ```

4. **Mass assignment bloqueado**:
   ```bash
   # Tentar criar usuário com role=administrador
   curl -X POST http://api/users \
     -d '{"email":"test@test.com","role":"administrador"}'
   # Deve rejeitar ou ignorar campo role
   ```

---

**Referências**:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
