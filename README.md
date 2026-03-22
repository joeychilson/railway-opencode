# Railway OpenCode

A one-click Railway template that runs an [OpenCode](https://opencode.ai) server with pre-configured skills and tools.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/h26SmG?referralCode=NhCCIt&utm_medium=integration&utm_source=template&utm_campaign=generic)

## What's included

**Tools** (via [mise](https://mise.jdx.dev)):
- Node.js, Python, Bun, Go
- pnpm, uv, gh

**Skills**:
- [use-railway](https://skills.sh/railwayapp/railway-skills/use-railway) — deploy and manage Railway services
- [find-skills](https://skills.sh/vercel-labs/skills/find-skills) — discover and install new skills
- use-mise — install and manage runtimes and tools

## Deploy

Set `OPENCODE_SERVER_PASSWORD` as a service variable during deploy.

## Connect

```bash
opencode attach https://your-app.railway.app -p your-password
```

## Local development

```bash
docker build -t railway-opencode .
docker run --rm -e OPENCODE_SERVER_PASSWORD=test -p 4096:4096 railway-opencode
opencode attach http://localhost:4096 -p test
```
