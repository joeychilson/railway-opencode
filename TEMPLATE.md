# Deploy and Host OpenCode with Railway

OpenCode is an open-source AI coding agent. This template runs an OpenCode 2
server you can use from a browser, from the OpenCode TUI on your own machine,
or through its API. It keeps your workspace, sessions, and credentials on a
volume and comes with the runtimes and tools an agent needs to build and ship
code.

## About Hosting OpenCode

The template runs one OpenCode service from a tested image for amd64 and arm64,
with a volume at `/var/lib/opencode` and a public domain. A generated password
protects the web UI and the API, and the server refuses to start without one.
Node.js, Python, Go, Bun, pnpm, uv, the GitHub CLI, the Railway CLI, and
headless Chromium are preinstalled, along with skills for Railway, browser
automation, and frontend design. The agent can install more tools with mise,
and they persist on the volume. Patch releases of the image install
automatically during Railway's nightly update window.

## Common Use Cases

- A coding agent that keeps working when your laptop is closed
- One OpenCode server shared between your browser, terminal, and scripts
- Agents that build, test, and deploy Railway services with the Railway CLI
- Browser automation and web testing with headless Chromium

## Dependencies for OpenCode Hosting

- An API key for a model provider, such as Anthropic, OpenAI, or OpenRouter,
  or a provider sign-in from the web UI

### Deployment Dependencies

- [OpenCode 2 documentation](https://opencode.ai/v2/docs)
- [Template source and full README](https://github.com/joeychilson/railway-opencode)

### Implementation Details

After deploying, add a provider key such as `ANTHROPIC_API_KEY` to the service
variables, then open the service's domain and sign in with `OPENCODE_PASSWORD`.

To use the TUI on your machine, install OpenCode 2 and connect to the server:

```bash
OPENCODE_PASSWORD=your-password opencode --server https://your-app.up.railway.app
```

Set `GITHUB_TOKEN` to let the agent push to GitHub, and `GIT_USER_NAME` and
`GIT_USER_EMAIL` to sign its commits. Keep Serverless sleeping off, because
sleeping interrupts running sessions.

### Why Deploy OpenCode on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will
host your infrastructure so you don't have to deal with configuration, while
allowing you to vertically and horizontally scale it.

By deploying OpenCode on Railway, you are one step closer to supporting a
complete full-stack application with minimal burden. Host your servers,
databases, AI agents, and more on Railway.
