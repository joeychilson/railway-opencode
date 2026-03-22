#!/bin/bash
set -e

[[ ! -d "$HOME/.mise" ]] && cp -a /opt/seed/. "$HOME/" 2>/dev/null || true

eval "$(mise activate bash)"

[[ -n "$GIT_USER_NAME" ]] && git config --global user.name "$GIT_USER_NAME"
[[ -n "$GIT_USER_EMAIL" ]] && git config --global user.email "$GIT_USER_EMAIL"
[[ -n "$GITHUB_TOKEN" ]] && echo "$GITHUB_TOKEN" | gh auth login --with-token

exec opencode serve --hostname 0.0.0.0 --port "${PORT:-4096}"
