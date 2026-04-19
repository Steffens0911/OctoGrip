# Estágio 1: build do Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# URL da API (o browser acessa pelo host; em Docker no mesmo host = localhost:8000)
ARG API_BASE_URL=http://localhost:8000
# FCM Web (opcional): mesmo appId que no Firebase Console (app Web) + chave pública VAPID
ARG FIREBASE_WEB_APP_ID=
ARG FCM_VAPID_KEY=

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
# Alinhar service worker ao appId usado no Dart (--dart-define)
RUN if [ -n "$FIREBASE_WEB_APP_ID" ]; then \
      sed -i.bak "s|__FIREBASE_WEB_APP_ID__|$FIREBASE_WEB_APP_ID|g" web/firebase-messaging-sw.js && \
      rm -f web/firebase-messaging-sw.js.bak; \
    fi
RUN flutter build web --release \
      --dart-define=API_BASE_URL=$API_BASE_URL \
      --dart-define=FIREBASE_WEB_APP_ID=$FIREBASE_WEB_APP_ID \
      --dart-define=FCM_VAPID_KEY=$FCM_VAPID_KEY

# Estágio 2: servir com nginx
FROM nginx:alpine

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
