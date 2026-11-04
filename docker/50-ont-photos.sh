#!/bin/sh
# Runs from nginx's /docker-entrypoint.d before nginx starts. Starts the
# photo service (photos-service/, proxied by nginx at /photos-api/) in the
# background and restarts it whenever it stops, so a crash never leaves the
# app without photo sync until the next container restart. nginx stays
# PID 1; stopping the container stops both.
set -eu

mkdir -p "${PHOTOS_DIR:-/data/photos}"
(
  while :; do
    /usr/local/bin/ont-photos || true
    echo "50-ont-photos: photo service stopped; restarting in 2 s" >&2
    sleep 2
  done
) </dev/null &
echo "50-ont-photos: photo service started"
