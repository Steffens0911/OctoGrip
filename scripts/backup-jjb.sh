#!/bin/bash
set -euo pipefail

BACKUP_DIR="/tmp/jjb_backups"
GDRIVE_DEST="gdrive:backups/jjb"
MEDIA_DIR="/var/lib/docker/volumes/kbh2m6vpdr719pzfwfotbgxh_api-media/_data"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
FILENAME="jjb_db_${TIMESTAMP}.sql.gz"
MEDIA_FILENAME="jjb_media_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Iniciando backup do banco..."

POSTGRES_CONTAINER=$(docker ps --filter "name=postgres-kbh2m6vpdr" --format "{{.Names}}" | head -1)

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo "[$(date)] ERRO: container postgres não encontrado. Abortando." >&2
  exit 1
fi

docker exec "$POSTGRES_CONTAINER" pg_dump \
  -U jjb \
  jjb_db \
  | gzip > "${BACKUP_DIR}/${FILENAME}"

echo "[$(date)] Banco: $(du -sh "${BACKUP_DIR}/${FILENAME}" | cut -f1)"

echo "[$(date)] Iniciando backup da mídia..."

tar -czf "${BACKUP_DIR}/${MEDIA_FILENAME}" -C "$MEDIA_DIR" .

echo "[$(date)] Mídia: $(du -sh "${BACKUP_DIR}/${MEDIA_FILENAME}" | cut -f1)"

rclone copy "${BACKUP_DIR}/${FILENAME}" "$GDRIVE_DEST"
rclone copy "${BACKUP_DIR}/${MEDIA_FILENAME}" "$GDRIVE_DEST"

echo "[$(date)] Upload concluído para ${GDRIVE_DEST}"

find "$BACKUP_DIR" -name "*.sql.gz" -mtime +2 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +2 -delete

rclone delete "$GDRIVE_DEST" --min-age 30d

echo "[$(date)] Limpeza concluída. Done."
