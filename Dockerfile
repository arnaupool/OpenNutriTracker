# Multi-stage build: compile the Flutter web app, then serve the static
# output with a tiny nginx image. The final image never contains the
# Flutter SDK, source code, or build cache — only build/web/.
#
# The hash-based URL strategy (default, unchanged — see docs/deploy-docker.md)
# means nginx only ever needs to serve real files (index.html, main.dart.js,
# assets/, icons/, manifest.json, flutter_service_worker.js); no SPA
# fallback / rewrite rule is required.

FROM ghcr.io/cirruslabs/flutter:3.41.7 AS build
WORKDIR /app

# Copy dependency manifests first so `flutter pub get` is cached across
# builds that only change application code.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Only what flutter build web actually reads. In particular: no android/,
# ios/, test/ — keeps the image build fast and avoids invalidating the
# Docker layer cache on unrelated native-platform changes.
COPY analysis_options.yaml ./
COPY lib/ lib/
COPY web/ web/
COPY assets/ assets/
COPY fonts/ fonts/

# .env carries the real secrets (Supabase, Sentry, FDC) baked in at build
# time by envied — see docs/deploy-docker.md for how to create it on the
# server before running `docker compose build`. This is the same file
# `just build` reads locally; nothing Docker-specific about its contents.
COPY .env ./
RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter build web --release

FROM nginx:1.27-alpine AS serve
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
