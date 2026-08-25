# OpenCode on Railway

[![CI](https://github.com/joeychilson/railway-opencode/actions/workflows/ci.yml/badge.svg)](https://github.com/joeychilson/railway-opencode/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/joeychilson/railway-opencode)](https://github.com/joeychilson/railway-opencode/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Railway template for running a persistent, password-protected
[OpenCode](https://opencode.ai) server with a web UI, remote TUI, API, developer
tools, agent skills, and browser automation.

## Deployment

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-for-railway?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

The template provides:

- A pinned OpenCode release for AMD64 and ARM64.
- HTTP basic authentication on every route.
- A persistent volume at `/var/lib/opencode`.
- A workspace that survives redeployments.
- Node.js, Python, Go, Bun, pnpm, uv, GitHub CLI, and Railway CLI through
  [mise](https://mise.jdx.dev).
- Headless Chromium and
  [agent-browser](https://skills.sh/vercel-labs/agent-browser/agent-browser).
- Preinstalled skills for Railway, browser automation, frontend design, skill
  creation, tool installation, and skill discovery.

Set `OPENCODE_SERVER_PASSWORD` and at least one model provider API key before
deploying. The server refuses to start without a password unless unauthenticated
mode is enabled explicitly.

## Connect

Open the Railway domain in a browser and sign in with username `opencode` and
the configured password.

Attach the OpenCode TUI from a local machine:

```text
opencode attach https://your-app.up.railway.app -p your-password
```

Run a one-shot prompt:

```text
OPENCODE_SERVER_PASSWORD=your-password \
  opencode run --attach https://your-app.up.railway.app "fix the failing tests"
```

Connect with the TypeScript SDK:

```ts
import { createOpencodeClient } from "@opencode-ai/sdk"

const client = createOpencodeClient({
  baseUrl: "https://opencode:your-password@your-app.up.railway.app",
})
```

The OpenAPI specification is available at `/doc`, and server-sent events are
available at `/event`.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | None | Required basic-auth password |
| `OPENCODE_SERVER_USERNAME` | `opencode` | Basic-auth username |
| `OPENCODE_ALLOW_UNAUTHENTICATED` | None | Set to `1` only for private-network-only deployments |
| `OPENCODE_HOSTNAME` | `::` | Dual-stack listen address |
| `PORT` | `4096` | Server port |
| `GIT_USER_NAME` | None | Git commit name |
| `GIT_USER_EMAIL` | None | Git commit email |
| `GITHUB_TOKEN` or `GH_TOKEN` | None | Authenticate GitHub CLI and Git over HTTPS |
| `OPENCODE_CONFIG_CONTENT` | None | JSON merged into the OpenCode configuration |

OpenCode reads provider credentials from the environment. Supported variables
include `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`,
`GOOGLE_API_KEY`, `XAI_API_KEY`, `GROQ_API_KEY`, `MISTRAL_API_KEY`, and
`DEEPSEEK_API_KEY`, along with AWS, Vertex AI, and Azure credentials.

Credentials added through OpenCode, including provider OAuth credentials, are
stored on the volume. The baked configuration disables sharing and automatic
updates. Extend it with `OPENCODE_CONFIG_CONTENT` or a project-level
`opencode.json` file.

## Persistence

The Railway volume is mounted at `/var/lib/opencode`, which is also the runtime
user's home directory. It stores:

- The default project in `workspace/`.
- Sessions, logs, and provider credentials.
- Tools and skills installed at runtime.
- Git and GitHub CLI configuration.

The OpenCode binary, baked skills, default configuration, Chromium, and system
packages remain in the image. On an image update, managed defaults are refreshed
without replacing workspace files or OpenCode state.

Keep Serverless sleeping disabled because sleeping interrupts active sessions.
A volume-backed service also has a brief downtime window during redeployment
because Railway cannot mount one volume in two containers.

Install additional tools and skills without root access:

```text
mise use <tool>@<version>
npx skills add <package> -a opencode -y
```

## Private networking

For access only from services in the same Railway project, remove the public
domain and connect to:

```text
http://<service-name>.railway.internal:4096
```

This is the only recommended setup for `OPENCODE_ALLOW_UNAUTHENTICATED=1`.

For a manual Railway deployment, use
`ghcr.io/joeychilson/railway-opencode:<version>`, attach a volume at
`/var/lib/opencode`, configure authentication and a provider, and attach a
public domain to port `4096` when external access is required.

## Updates

Images are published only from GitHub releases. The wrapper uses its own
semantic version, independently from OpenCode. Exact `X.Y.Z` and
`sha-<commit>` tags are immutable, while `X.Y` tracks the latest compatible
patch release. There is no `latest` tag.

The OpenCode version is pinned in the `Dockerfile`. A scheduled workflow checks
for new releases and opens a pull request. CI smoke-tests each update before it
is reviewed and released. See [RELEASING.md](RELEASING.md) for the release
policy.

Redeploy the service to update. Workspace files, sessions, and credentials
remain on the volume.

## Development

```text
docker build -t railway-opencode:test .
./test/smoke-test.sh railway-opencode:test

docker run --rm \
  -e OPENCODE_SERVER_PASSWORD=test \
  -p 4096:4096 \
  railway-opencode:test
```

The smoke test verifies authentication, preinstalled tools and skills, the
seeded workspace, persistent state, volume ownership, and the missing-password
guard.

## License

[MIT](LICENSE)
