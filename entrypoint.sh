#!/bin/bash
set -euo pipefail

# ── Phase 1: root ────────────────────────────────────────────────────────────
# Railway mounts volumes owned by root. Hand $HOME to the unprivileged
# opencode user, then re-exec this script as that user.
if [[ "$(id -u)" == "0" ]]; then
  if [[ "$(stat -c '%U' "$HOME")" != "opencode" ]]; then
    echo "entrypoint: taking ownership of $HOME (first boot or migrated volume)"
    chown -R opencode:opencode "$HOME"
  fi
  exec gosu opencode "$0" "$@"
fi

# ── Phase 2: opencode user ───────────────────────────────────────────────────

# Refuse to expose an unauthenticated server. Railway gives this service a
# public URL, and without a password anyone on the internet can execute code
# and spend your API credits.
if [[ -z "${OPENCODE_SERVER_PASSWORD:-}" && "${OPENCODE_ALLOW_UNAUTHENTICATED:-}" != "1" ]]; then
  cat >&2 <<'EOF'
ERROR: OPENCODE_SERVER_PASSWORD is not set.

Set the OPENCODE_SERVER_PASSWORD service variable to protect this server with
HTTP basic auth (username "opencode", or set OPENCODE_SERVER_USERNAME).

If you intentionally run without auth (e.g. private networking only, with no
public domain), set OPENCODE_ALLOW_UNAUTHENTICATED=1.
EOF
  exit 1
fi

# First boot: populate the empty volume from the image seed. Image upgrade
# (seed stamp changed): overlay the seed again so image-managed files — mise
# tools, the default mise config, .bashrc — match this image. Files you
# created are left in place; opencode sessions/auth are never part of the seed.
seed_stamp="$(cat /opt/seed/.seed-stamp 2>/dev/null || echo unknown)"
home_stamp="$(cat "$HOME/.seed-stamp" 2>/dev/null || echo none)"
if [[ "$seed_stamp" != "$home_stamp" ]]; then
  echo "entrypoint: syncing image seed into $HOME ($home_stamp -> $seed_stamp)"
  cp -a /opt/seed/. "$HOME"/
  mise reshim || true
fi

# Persistence sanity check: on Railway, state survives redeploys only if a
# volume is mounted at $HOME.
if [[ -n "${RAILWAY_ENVIRONMENT_ID:-}" && "${RAILWAY_VOLUME_MOUNT_PATH:-}" != "$HOME" ]]; then
  echo "WARNING: no volume is mounted at $HOME — sessions, credentials, and" >&2
  echo "WARNING: workspace files will be LOST on every redeploy. Attach a" >&2
  echo "WARNING: volume with mount path $HOME to this service." >&2
fi

# Optional git identity + GitHub auth. Never fatal: a bad token should not
# take the server down.
if [[ -n "${GIT_USER_NAME:-}" ]]; then
  git config --global user.name "$GIT_USER_NAME" || true
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  git config --global user.email "$GIT_USER_EMAIL" || true
fi
if [[ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]]; then
  # gh uses the env token automatically; setup-git wires it into git https.
  gh auth setup-git >/dev/null 2>&1 || echo "WARNING: gh auth setup-git failed" >&2
fi

# Default project directory, seeded with environment notes for agents.
mkdir -p "$HOME/workspace"
if [[ ! -f "$HOME/workspace/AGENTS.md" ]]; then
  cp /opt/opencode/AGENTS.md "$HOME/workspace/AGENTS.md"
fi
cd "$HOME/workspace"

# Explicit path: the image's pinned opencode always wins over anything a
# session may have installed into the mise shims dir on the volume.
# "::" binds dual-stack: IPv4 for Railway's public edge, IPv6 for Railway
# private networking (legacy environments are IPv6-only internally).
exec /usr/local/bin/opencode serve \
  --hostname "${OPENCODE_HOSTNAME:-::}" \
  --port "${PORT:-4096}" \
  --print-logs
