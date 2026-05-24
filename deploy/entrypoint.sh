#!/usr/bin/env sh
set -eu

APP_UID="${APP_UID:-1000}"
APP_GID="${APP_GID:-1000}"
MEDIA_DIR="${MEDIA_DIR:-/app/app_media}"
FACE_JOBS_DIR="${FACE_JOBS_DIR:-/app/app_media/face_jobs}"

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$MEDIA_DIR" "$FACE_JOBS_DIR" || true
  chown -R "$APP_UID:$APP_GID" "$MEDIA_DIR" || true
  chmod -R u+rwX,g+rwX "$MEDIA_DIR" || true
  exec gosu "$APP_UID:$APP_GID" "$0" "$@"
fi

if [ "${BOOTSTRAP_ON_STARTUP:-true}" = "true" ] && [ "${1:-}" = "uvicorn" ]; then
  python -m app.bootstrap
fi

exec "$@"

