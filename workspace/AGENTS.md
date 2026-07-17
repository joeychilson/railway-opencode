# Environment

You are running on an OpenCode server deployed on Railway (a Linux container,
Debian). This file describes the environment so you can work effectively.

## Persistence

- Everything under `/var/lib/opencode` (the home directory) lives on a
  persistent volume: this workspace, sessions, credentials, and any tools you
  install survive restarts and redeploys.
- Anything outside the home directory is reset on every deploy.

## Installing tools

- You are NOT root and there is no sudo — `apt-get` will not work.
- Use **mise** for languages, runtimes, and CLIs (see the `use-mise` skill):
  `mise use rust@latest`, `mise use npm:prettier`, `mise use pipx:httpie`,
  `mise use github:astral-sh/ruff`, etc.
- Preinstalled: node, python, go, bun, pnpm, uv, gh (GitHub CLI),
  railway (Railway CLI), git, ripgrep, jq, curl, zip/unzip,
  build-essential (gcc/make for native modules).

## Browser

- Headless Chromium is installed at `/usr/bin/chromium` (`CHROME_PATH` is
  set). The `agent-browser` CLI and skill are available for browser
  automation.

## Networking

- This server sits behind Railway's edge; other services in the same Railway
  environment are reachable over private networking at
  `http://<service>.railway.internal:<port>`.
- To expose something you build here, deploy it as its own Railway service
  (use the `use-railway` skill and the `railway` CLI) rather than binding
  extra ports on this container.

## GitHub

- If `GITHUB_TOKEN` is set, `gh` and git-over-https authentication are already
  configured.
