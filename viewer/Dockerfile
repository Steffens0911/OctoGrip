# Estágio 1: build do Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# URL da API (o browser acede pelo host; em Docker no mesmo host = localhost:8000)
ARG API_BASE_URL=http://localhost:8000
# FCM Web: copiar do snippet "firebaseConfig" da app Web na consola (todos do MESMO objecto).
ARG FIREBASE_WEB_APP_ID=
ARG FIREBASE_WEB_API_KEY=
ARG FIREBASE_MESSAGING_SENDER_ID=
ARG FIREBASE_PROJECT_ID=
ARG FIREBASE_AUTH_DOMAIN=
ARG FIREBASE_STORAGE_BUCKET=
ARG FCM_VAPID_KEY=

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
# JSON + Python evitam shell/sed a partir com aspas ou caracteres especiais nas env vars do Coolify.
RUN set -e; \
  export API_BASE_URL="${API_BASE_URL}"; \
  export FIREBASE_WEB_APP_ID="${FIREBASE_WEB_APP_ID}"; \
  export FIREBASE_WEB_API_KEY="${FIREBASE_WEB_API_KEY}"; \
  export FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID}"; \
  export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID}"; \
  export FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN}"; \
  export FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET}"; \
  export FCM_VAPID_KEY="${FCM_VAPID_KEY}"; \
  python3 tool/prepare_firebase_web_build.py && \
  flutter build web --release \
    --dart-define-from-file=tool/dart_define_web.json

# Estágio 2: servir com nginx
FROM nginx:alpine

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
