# OpenCode on Railway

A one-click [Railway](https://railway.com) template that runs a persistent,
password-protected [OpenCode](https://opencode.ai) server — use it from the
**built-in web UI**, the **`opencode attach` TUI**, or the **HTTP API/SDK** —
preloaded with dev runtimes (via [mise](https://mise.jdx.dev)), agent skills,
and headless Chromium for browser automation.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-for-railway?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What you get

- **A headless OpenCode server** (`opencode serve`) pinned to a specific
  release, protected by HTTP basic auth on every route, with sharing disabled
  and autoupdate off. Railway terminates TLS at the edge, so credentials are
  never sent in plaintext.
- **The OpenCode web UI** at your Railway URL — open it in any browser, log in
  with the generated password, and code from anywhere (including your phone).
- **Persistent state** — the workspace, sessions, provider credentials, and
  any tools you install live on a Railway volume and survive redeploys.
- **A real dev toolchain** managed by mise: Node 24, Python 3.13, Go, Bun,
  pnpm, uv, gh (GitHub CLI), railway (Railway CLI), plus git, ripgrep, jq,
  and build-essential for native modules. Agents can install anything else
  with `mise use <tool>` — no root needed.
- **Headless Chromium** + the [agent-browser](https://skills.sh/vercel-labs/agent-browser/agent-browser)
  CLI for browser automation.

**Skills** (baked into the image, upgraded with it):

| Skill | Purpose |
|---|---|
| [use-railway](https://skills.sh/railwayapp/railway-skills/use-railway) | deploy and manage Railway services from the agent |
| [agent-browser](https://skills.sh/vercel-labs/agent-browser/agent-browser) | drive the headless browser |
| [skill-creator](https://skills.sh/anthropics/skills/skill-creator) | write new skills |
| [frontend-design](https://skills.sh/anthropics/skills/frontend-design) | frontend design guidance |
| find-skills | discover and install more skills from [skills.sh](https://skills.sh) |
| use-mise | install runtimes and CLIs at runtime |

Skills you install at runtime (`npx skills add <pkg> -a opencode -y`) go to
the volume and persist.

## Deploy

Deploy the template. It prompts for:

| Variable | Notes |
|---|---|
| `OPENCODE_SERVER_PASSWORD` | auto-generated (`${{secret()}}`) — the basic-auth password for the server and web UI |
| `ANTHROPIC_API_KEY` (or another provider key) | at least one provider key so the agent can run |

The server **refuses to boot without a password** (see
`OPENCODE_ALLOW_UNAUTHENTICATED` below), because a Railway deployment is
public by default and an open OpenCode server means arbitrary code execution
plus your API credits.

## Connect

**Browser** — open `https://your-app.up.railway.app`, log in with username
`opencode` and your password.

**TUI** from your machine:

```bash
opencode attach https://your-app.up.railway.app -p your-password
```

**One-shot prompts / scripting:**

```bash
OPENCODE_SERVER_PASSWORD=your-password \
  opencode run --attach https://your-app.up.railway.app "fix the failing tests"
```

**SDK:**

```ts
import { createOpencodeClient } from "@opencode-ai/sdk"

const client = createOpencodeClient({
  baseUrl: "https://opencode:your-password@your-app.up.railway.app",
})
```

The OpenAPI spec is served at `/doc`, server-sent events at `/event`.

## Model providers

OpenCode picks up provider API keys from the environment automatically — set
any of these as service variables: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
`OPENROUTER_API_KEY`, `GOOGLE_API_KEY`, `XAI_API_KEY`, `GROQ_API_KEY`,
`MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`, or AWS/Vertex/Azure credentials.

Credentials added at runtime (e.g. Claude Pro/Max OAuth via the `/connect`
command) are stored in `auth.json` on the volume and persist.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | – | **required** — basic-auth password for all routes |
| `OPENCODE_SERVER_USERNAME` | `opencode` | basic-auth username |
| `OPENCODE_ALLOW_UNAUTHENTICATED` | – | set `1` to boot without a password (only for private-networking-only setups with no public domain) |
| `OPENCODE_HOSTNAME` | `::` | listen address (`::` = IPv4 + IPv6, needed for Railway private networking) |
| `PORT` | `4096` | listen port (Railway sets this) |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | – | git commit identity |
| `GITHUB_TOKEN` | – | authenticates `gh` and git-over-https |
| `OPENCODE_CONFIG_CONTENT` | – | inline JSON merged into the opencode config — e.g. `{"model":"anthropic/claude-sonnet-4-5"}` |

Baked config (`/opt/opencode/opencode.json`): `share: disabled`,
`autoupdate: false` (upgrades come from image releases), plus the baked
skills path. Override or extend via `OPENCODE_CONFIG_CONTENT` or a project
`opencode.json` in the workspace.

## Persistence and upgrades

The Railway volume is mounted at `/var/lib/opencode` (the home directory):

- **On the volume (persists):** `workspace/` (default project dir),
  `~/.local/share/opencode` (sessions, `auth.json`, logs), runtime-installed
  mise tools and skills, git/gh config.
- **In the image (upgrades with each release):** the `opencode` binary, mise,
  baked skills and config, Chromium, system packages.

On the first boot the volume is populated from the image seed. When you
deploy a newer image, the seed is re-synced: preinstalled tools and defaults
are refreshed while your files stay put. Redeploys of volume-backed services
have a brief downtime window (Railway can't mount one volume in two
containers).

Because state is on the volume, **serverless/app-sleeping should stay off**
— sleeping kills in-flight sessions.

## Private-networking-only mode

If you only call the server from other services in the same Railway project,
you can remove the public domain entirely; the server stays reachable at
`http://<service-name>.railway.internal:4096`. That is the one setup where
running without a password (`OPENCODE_ALLOW_UNAUTHENTICATED=1`) is
reasonable.

## Deploying manually (outside the template)

1. Create a service from this repo (or the published image).
2. **Attach a volume with mount path `/var/lib/opencode`** — without it,
   everything is lost on each deploy (the server logs a loud warning).
3. Set `OPENCODE_SERVER_PASSWORD` and at least one provider API key.
4. Generate a public domain with target port `4096`.

## Local development

```bash
docker build -t railway-opencode:test .
./test/smoke-test.sh railway-opencode:test   # what CI runs

docker run --rm -e OPENCODE_SERVER_PASSWORD=test -p 4096:4096 railway-opencode:test
opencode attach http://localhost:4096 -p test    # or open http://localhost:4096
```

The smoke test boots the image the way Railway does (empty, root-owned
volume), then verifies auth, tools, skills, the seeded workspace, persistence
across a container replacement, and the no-password guard.

## Versioning and updates

The opencode version is pinned in the `Dockerfile` (`ARG OPENCODE_VERSION`)
so every published image ships a version that passed the smoke test. A daily
workflow checks npm for new opencode releases, bumps the pin, smoke-tests the
build, and — only on green — pushes to main, tags `v<opencode-version>`, and
publishes the image. **To update a deployed server, just redeploy** — it
rebuilds from the current pin; sessions, credentials, and workspace files are
preserved on the volume.

## License

MIT License
