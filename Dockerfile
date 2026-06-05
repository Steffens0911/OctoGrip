# Estágio 1: Builder - instala dependências já como usuário app (evita chown de 2GB no runtime)
FROM python:3.12-slim-bookworm AS builder

# Cria o mesmo usuário/grupo do runtime para o pip instalar no lugar certo
RUN groupadd --gid 1000 app && \
    useradd --uid 1000 --gid app --shell /bin/bash --create-home app

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/app/.local/bin:$PATH

# Copiar apenas requirements para otimizar cache de layers
COPY requirements.txt .

# Instala deps como usuário app → /home/app/.local (sem precisar de chown depois)
RUN pip install --upgrade pip && \
    pip install --user --no-warn-script-location -r requirements.txt

# Estágio 2: Runtime - imagem final
FROM python:3.12-slim-bookworm

WORKDIR /app

# Usuário não-root (segurança)
RUN groupadd --gid 1000 app && \
    useradd --uid 1000 --gid app --shell /bin/bash --create-home app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/app/.local/bin:$PATH \
    PYTHONPATH=/home/app/.local/lib/python3.12/site-packages

# Cliente PostgreSQL 16 (pg_dump/psql) — mesma major que o serviço postgres no compose (evita "server version mismatch")
# Dependências runtime para DeepFace/OpenCV (cv2): evita ImportError libxcb.so.1 (Coolify worker).
# Este bloco fica ANTES do COPY do builder para maximizar cache de layer — não invalida com mudanças de código ou deps Python.
RUN apt-get update && apt-get install -y --no-install-recommends \
      wget \
      ca-certificates \
      gosu \
      libxcb1 \
      libgl1 \
      libglib2.0-0 \
    && install -d /usr/share/postgresql-common/pgdg \
    && wget -qO /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Copia deps já com ownership correto — sem chown necessário
COPY --from=builder --chown=app:app /home/app/.local /home/app/.local

# Copiar código (ownership para app) e garantir permissão de escrita em /app/app_media
COPY --chown=app:app . .
RUN mkdir -p /app/app_media && chown app:app /app/app_media

COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

# Metadados OCI
LABEL org.opencontainers.image.title="JJB API" \
      org.opencontainers.image.description="API do MVP SaaS de ensino de jiu-jitsu" \
      org.opencontainers.image.source=""

# Healthcheck via endpoint /health
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').close()" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4", "--loop", "uvloop", "--http", "httptools", "--no-access-log"]
