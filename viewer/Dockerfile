# Estágio 1: build do Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# URL da API (o browser acessa pelo host; em Docker no mesmo host = localhost:8000)
ARG API_BASE_URL=http://localhost:8000

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# Estágio 2: servir com nginx
FROM nginx:alpine

COPY nginx.default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
