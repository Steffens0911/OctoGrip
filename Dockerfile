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
#
# deepface declara opencv-python (variante com GUI) como dependência própria, sem limite
# de versão superior — isso instala opencv-python JUNTO com o opencv-python-headless que
# pedimos no requirements.txt. Os dois pacotes escrevem no mesmo namespace cv2/, corrompendo
# cv2/data/ (falta o haarcascade_frontalface_default.xml e o DeepFace quebra com "Confirm
# that opencv is installed on your environment!"). Por isso removemos o opencv-python (GUI)
# se ele entrar como transitiva e reinstalamos o headless por cima, sozinho e sem
# dependências, garantindo que os arquivos de dados fiquem completos.
# Ver https://github.com/serengil/deepface/issues/595.
USER app
RUN pip install --upgrade pip --user && \
    pip install --user --no-warn-script-location -r requirements.txt && \
    (pip uninstall -y opencv-python || true) && \
    pip install --user --no-warn-script-location --force-reinstall --no-deps opencv-python-headless==4.10.0.84

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
# Mantido alinhado com o `command:` do docker-compose.yml. Plataformas como o Coolify
# podem usar ESTE CMD da imagem em vez do override do compose, então os flags críticos
# vivem aqui também:
#   --workers 2          : a API é leve (a inferência facial roda no celery-worker-face,
#                          nunca aqui); 2 workers async/uvloop servem a carga com folga.
#   --timeout-keep-alive 120 : evita o 502 intermitente da race de keep-alive com o proxy
#                          (uvicorn fechava em 5s e o Traefik reusava a conexão morta).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--loop", "uvloop", "--http", "httptools", "--no-access-log", "--timeout-keep-alive", "120"]
