# Estágio 1: Builder - instala dependências
FROM python:3.12-slim-bookworm AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Copiar apenas requirements para otimizar cache de layers
COPY requirements.txt .

# Atualizar pip e instalar dependências no diretório do usuário
RUN pip install --upgrade pip && \
    pip install --user -r requirements.txt

# Estágio 2: Runtime - imagem final
FROM python:3.12-slim-bookworm

WORKDIR /app

# Usuário não-root (segurança)
RUN groupadd --gid 1000 app && \
    useradd --uid 1000 --gid app --shell /bin/bash --create-home app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/app/.local/bin:$PATH

# Copiar dependências do builder para o usuário app
COPY --from=builder /root/.local /home/app/.local
RUN chown -R app:app /home/app/.local

# Copiar código (ownership para app) e garantir permissão de escrita em /app/app_media
COPY --chown=app:app . .
RUN mkdir -p /app/app_media && chown -R app:app /app

USER app

EXPOSE 8000

# Metadados OCI
LABEL org.opencontainers.image.title="JJB API" \
      org.opencontainers.image.description="API do MVP SaaS de ensino de jiu-jitsu" \
      org.opencontainers.image.source=""

# Healthcheck via endpoint /health
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').close()" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
