#!/bin/sh
# Docker healthcheck. Note: opencode requires basic auth on every route when
# OPENCODE_SERVER_PASSWORD is set (Railway's own healthchecks can't send
# auth headers, so Railway templates should not configure an HTTP healthcheck).
set -eu
port="${PORT:-4096}"
if [ -n "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  exec curl -fsS -o /dev/null -u "${OPENCODE_SERVER_USERNAME:-opencode}:${OPENCODE_SERVER_PASSWORD}" "http://127.0.0.1:${port}/app"
fi
exec curl -fsS -o /dev/null "http://127.0.0.1:${port}/app"
