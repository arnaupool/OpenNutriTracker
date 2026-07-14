# Multi-stage build: compile the Flutter web app, then serve the static
# output with a tiny nginx image. The final image never contains the
# Flutter SDK, source code, or build cache — only build/web/.
#
# The hash-based URL strategy (default, unchanged — see docs/deploy-docker.md)
# means nginx only ever needs to serve real files (index.html, main.dart.js,
# assets/, icons/, manifest.json, flutter_service_worker.js); no SPA
# fallback / rewrite rule is required.
#
# Build stage is a plain Debian image with the Flutter SDK fetched by hand,
# NOT ghcr.io/cirruslabs/flutter — that image bundles the full Android SDK
# and build-tools (multiple GB) unconditionally, which `flutter build web`
# never touches and which has been known to exhaust small Docker storage
# allocations (e.g. Unraid's default docker vDisk) for no reason.

FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.7-stable.tar.xz -o /tmp/flutter.tar.xz \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"

# Avoids a "detected dubious ownership" git error some Flutter tool
# commands hit when running as root against an SDK checkout it doesn't
# itself own the git history of.
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --web

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

# Secrets (Supabase, Sentry, FDC) arrive as build ARGs rather than a
# copied .env file, so this also works when Portainer clones the repo
# and builds it directly (Stacks -> Add stack -> Repository) — there's
# no straightforward way to inject an arbitrary file into that cloned
# tree, but Portainer's stack "Environment variables" UI maps cleanly
# onto compose build args. `docker compose build` also auto-populates
# these from a local .env file if one exists next to the compose file
# (standard Compose behaviour) — see docs/deploy-docker.md.
ARG SUPABASE_PROJECT_URL
ARG SUPABASE_PROJECT_ANON_KEY
ARG FDC_API_KEY
ARG SENTRY_DNS
RUN printf 'FDC_API_KEY="%s"\nSENTRY_DNS="%s"\nSUPABASE_PROJECT_URL="%s"\nSUPABASE_PROJECT_ANON_KEY="%s"\n' \
      "$FDC_API_KEY" "$SENTRY_DNS" "$SUPABASE_PROJECT_URL" "$SUPABASE_PROJECT_ANON_KEY" > .env

RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter build web --release

FROM nginx:1.27-alpine AS serve
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
