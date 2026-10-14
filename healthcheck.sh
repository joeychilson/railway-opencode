#!/bin/sh
# Docker healthcheck. /api/info answers 200 once the server is ready and
# needs the password; the web UI is served without one, so it can't show
# readiness.
set -eu
exec curl -fsS -o /dev/null \
  -u "opencode:${OPENCODE_PASSWORD:-${OPENCODE_SERVER_PASSWORD:-}}" \
  "http://127.0.0.1:${PORT:-4096}/api/info"
