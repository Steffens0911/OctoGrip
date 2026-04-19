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
# Alinhar firebase-messaging-sw.js aos --dart-define (Installations falha com 400 se apiKey ≠ appId).
RUN set -e; \
  D_API_KEY="${FIREBASE_WEB_API_KEY:-AIzaSyAby3LjFqiQysgqFJF3TDkFyIQbj7XeD2A}"; \
  D_APP_ID="${FIREBASE_WEB_APP_ID:-__FIREBASE_WEB_APP_ID__}"; \
  D_SENDER="${FIREBASE_MESSAGING_SENDER_ID:-914963189561}"; \
  D_PROJECT="${FIREBASE_PROJECT_ID:-octogrip}"; \
  D_AUTH="${FIREBASE_AUTH_DOMAIN:-octogrip.firebaseapp.com}"; \
  D_BUCKET="${FIREBASE_STORAGE_BUCKET:-octogrip.firebasestorage.app}"; \
  sed -i.bak \
    -e "s|__FIREBASE_WEB_API_KEY__|${D_API_KEY}|g" \
    -e "s|__FIREBASE_WEB_APP_ID__|${D_APP_ID}|g" \
    -e "s|__FIREBASE_MESSAGING_SENDER_ID__|${D_SENDER}|g" \
    -e "s|__FIREBASE_PROJECT_ID__|${D_PROJECT}|g" \
    -e "s|__FIREBASE_AUTH_DOMAIN__|${D_AUTH}|g" \
    -e "s|__FIREBASE_STORAGE_BUCKET__|${D_BUCKET}|g" \
    web/firebase-messaging-sw.js; \
  rm -f web/firebase-messaging-sw.js.bak; \
  flutter build web --release \
    --dart-define=API_BASE_URL=$API_BASE_URL \
    --dart-define=FIREBASE_WEB_APP_ID=$FIREBASE_WEB_APP_ID \
    --dart-define=FIREBASE_WEB_API_KEY=$D_API_KEY \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=$D_SENDER \
    --dart-define=FIREBASE_PROJECT_ID=$D_PROJECT \
    --dart-define=FIREBASE_AUTH_DOMAIN=$D_AUTH \
    --dart-define=FIREBASE_STORAGE_BUCKET=$D_BUCKET \
    --dart-define=FCM_VAPID_KEY=$FCM_VAPID_KEY

# Estágio 2: servir com nginx
FROM nginx:alpine

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
