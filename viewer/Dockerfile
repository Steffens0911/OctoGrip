# Estágio 1: build do Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

ARG API_BASE_URL=http://localhost:8001
ARG FIREBASE_WEB_APP_ID=
ARG FIREBASE_WEB_API_KEY=
ARG FIREBASE_MESSAGING_SENDER_ID=
ARG FIREBASE_PROJECT_ID=
ARG FIREBASE_AUTH_DOMAIN=
ARG FIREBASE_STORAGE_BUCKET=
ARG FCM_VAPID_KEY=

ENV API_BASE_URL=${API_BASE_URL}
ENV FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID}
ENV FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY}
ENV FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}
ENV FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
ENV FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}
ENV FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}
ENV FCM_VAPID_KEY=${FCM_VAPID_KEY}

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .

RUN python3 tool/prepare_firebase_web_build.py

RUN flutter precache --web

RUN flutter build web --release \
    --no-pub \
    --no-wasm-dry-run \
    --dart-define-from-file=tool/dart_define_web.json \
    || (flutter build web --release --no-pub --no-wasm-dry-run --dart-define-from-file=tool/dart_define_web.json --verbose 2>&1 | tail -100 && exit 1)

# Estágio 2: servir com nginx
FROM nginx:alpine

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
