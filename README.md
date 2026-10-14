# OpenCode on Railway

[![Release](https://img.shields.io/github/v/release/joeychilson/railway-opencode)](https://github.com/joeychilson/railway-opencode/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Railway template for a persistent, password-protected
[OpenCode](https://opencode.ai) 2 server with a web UI, an API, developer
tools, agent skills, and browser automation.

## Deploy

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-for-railway?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

The template creates one `opencode` service with:

- The `ghcr.io/joeychilson/railway-opencode` image for amd64 and arm64.
- A generated `OPENCODE_PASSWORD`.
- A volume at `/var/lib/opencode` for the workspace, sessions, and credentials.
- A public domain on port `4096`.
- Node.js, Python, Go, Bun, pnpm, uv, the GitHub CLI, and the Railway CLI
  through [mise](https://mise.jdx.dev).
- Headless Chromium and
  [agent-browser](https://skills.sh/vercel-labs/agent-browser/agent-browser).
- Skills for Railway, browser automation, frontend design, skill creation,
  installing tools, and finding more skills.

Add at least one model provider key, such as `ANTHROPIC_API_KEY`, or sign in to
a provider from the web UI after deploying. The server refuses to start without
a password.

To deploy the image without the template, use
`ghcr.io/joeychilson/railway-opencode:<version>`, attach a volume at
`/var/lib/opencode`, set `OPENCODE_PASSWORD`, and attach a public domain to
port `4096`.

## Usage

Open the Railway domain in a browser and sign in with the password.

Remote clients need OpenCode 2 on your machine. Open the TUI against the server:

```text
OPENCODE_PASSWORD=your-password opencode --server https://your-app.up.railway.app
```

Run a one-shot prompt:

```text
OPENCODE_PASSWORD=your-password \
  opencode run --server https://your-app.up.railway.app "fix the failing tests"
```

Connect with the TypeScript client:

```ts
import { OpenCode } from "@opencode/client"

const client = OpenCode.make({
  baseUrl: "https://your-app.up.railway.app",
  headers: { authorization: `Basic ${btoa("opencode:your-password")}` },
})
```

The API is under `/api` and uses HTTP basic auth with the username `opencode`.
The OpenAPI document is at `/openapi.json`, and server-sent events are at
`/api/event`. The web UI itself loads without a password and then asks for one.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `OPENCODE_PASSWORD` | Generated | Password for the web UI, API, and remote clients. `OPENCODE_SERVER_PASSWORD` also works. |
| `GIT_USER_NAME` | None | Name on Git commits |
| `GIT_USER_EMAIL` | None | Email on Git commits |
| `GITHUB_TOKEN` or `GH_TOKEN` | None | Signs in the GitHub CLI and Git over HTTPS |
| `RAILWAY_API_TOKEN` | None | Signs in the Railway CLI |
| `OPENCODE_CONFIG_CONTENT` | None | JSON merged into the OpenCode configuration |
| `OPENCODE_HOSTNAME` | `::` | Listen address; `::` covers IPv4 and IPv6 |
| `PORT` | `4096` | Server port |

OpenCode reads provider keys from the environment, including
`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_API_KEY`,
`XAI_API_KEY`, `GROQ_API_KEY`, `MISTRAL_API_KEY`, and `DEEPSEEK_API_KEY`.
Credentials you add in OpenCode, including provider sign-ins, are stored on the
volume.

The baked configuration turns off session sharing and self-updates. Extend it
with `OPENCODE_CONFIG_CONTENT` or an `opencode.json` in a project.

## Persistence

The volume at `/var/lib/opencode` is also the home directory. It holds:

- The default project in `workspace/`.
- Sessions, logs, and credentials.
- Tools and skills installed at runtime.
- Git and GitHub CLI configuration.

The OpenCode binary, the baked skills and configuration, Chromium, and system
packages live in the image. When the image changes, the entrypoint refreshes
the image-managed files on the volume and leaves your files and OpenCode state
alone.

Install more tools and skills without root:

```text
mise use <tool>@<version>
npx skills add <package> -a opencode -y
```

Keep Serverless sleeping off, because sleeping interrupts running sessions. A
redeploy has a short outage, since one volume can't be mounted in two
containers at once.

For access only from services in the same project, remove the public domain
and connect to `http://opencode.railway.internal:4096`.

## Updates

Each release is published as `ghcr.io/joeychilson/railway-opencode:X.Y.Z` and
moves the `X.Y` tag to it. The Railway template deploys `X.Y` with patch
auto-updates on, so a deployment that keeps that setting picks up patch releases
in Railway's nightly update window. A minor or major release starts a new `X.Y`
tag, and its release notes say what to change before you move to it. Workspace
files, sessions, and credentials stay on the volume across updates.

[Renovate](https://docs.renovatebot.com) bumps OpenCode when a new release is 2
days old. The bump merges after the smoke test passes on amd64 and arm64, and
the merge publishes a patch release. New OpenCode majors and new Node.js or
Python lines wait for review, and a new runtime line releases as a major. The
release policy for all of these templates is in
[railway-templates](https://github.com/joeychilson/railway-templates#releases).

### Upgrading from 3.x

Version 4.0 moves the default Node.js from 24 to 26 and Python from 3.13 to
3.15. Change the image to `ghcr.io/joeychilson/railway-opencode:4.0`.

Node.js 24 and Python 3.13 stay installed on the volume, so existing virtual
environments keep working. To keep a project on the old versions, run
`mise use node@24 python@3.13` in its directory.

### Upgrading from 2.x

Versions 2.x run OpenCode 1. Version 3.0 moves to OpenCode 2, which changes
the clients and the API:

1. Back up the volume. OpenCode 2 migrates sessions and credentials on its
   first boot, and OpenCode 1 can't use the volume afterwards.
2. Change the image to `ghcr.io/joeychilson/railway-opencode:3.0` and set the
   healthcheck path to `/`.
3. Rename `OPENCODE_SERVER_PASSWORD` to `OPENCODE_PASSWORD`. The old name
   still works.
4. Remove `OPENCODE_SERVER_USERNAME` and `OPENCODE_ALLOW_UNAUTHENTICATED`. The
   username is always `opencode`, and a password is always required.
5. Upgrade local clients to OpenCode 2. `opencode attach URL` is now
   `opencode --server URL`, and `/doc` moved to `/openapi.json`.

## Development

```text
docker build -t railway-opencode:test .
./test/smoke-test.sh railway-opencode:test
```

The smoke test boots the image on an empty volume and checks the password
guard, API authentication, the web UI, the tools and skills, the seeded
workspace, volume ownership, and persistence across a container replacement.
To run the image yourself:

```text
docker run --rm -e OPENCODE_PASSWORD=test -p 4096:4096 railway-opencode:test
```

## License

[MIT](LICENSE)
