#!/bin/sh
# Runs from nginx's /docker-entrypoint.d before nginx starts. Creates a
# self-signed certificate for the HTTPS server block the first time the
# container starts, unless one is already in /certs (mount a volume there
# to keep it across updates, or to use your own cert.pem / key.pem).
set -eu

CERT_DIR=/certs
if [ -s "$CERT_DIR/cert.pem" ] && [ -s "$CERT_DIR/key.pem" ]; then
  exit 0
fi

mkdir -p "$CERT_DIR"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=opennutritracker" \
  -addext "subjectAltName=DNS:opennutritracker,DNS:localhost,IP:127.0.0.1" \
  -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" >/dev/null 2>&1
echo "40-ont-self-signed-cert: generated a self-signed certificate in $CERT_DIR"
