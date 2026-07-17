---
name: use-mise
description: Use mise to install and manage language runtimes, tools, and CLIs on this server
---

## What is mise

mise is the tool manager on this server. It installs and manages language runtimes (node, python, go, rust, bun), package managers (pnpm, uv), and CLIs (gh, railway).

## Pre-installed tools

These are already available — no installation needed:

- `node`, `python`, `bun`, `go`
- `pnpm`, `uv`
- `gh` (GitHub CLI), `railway` (Railway CLI)

Run `mise list` to see exact versions.

## Installing additional tools

```bash
# Search the registry for available tools
mise registry

# Install a registry tool
mise install rust@latest
mise use rust@latest

# Install a specific version
mise install node@20
mise use node@20
```

## Installing from other sources

mise can install tools from npm, pipx, and GitHub releases directly:

```bash
# npm packages
mise use npm:cowsay
mise use npm:prettier
mise use npm:@railway/cli

# Python CLI tools (via pipx)
mise use pipx:copier
mise use pipx:httpie
mise use pipx:poetry

# GitHub releases
mise use github:codefresh-io/cli
mise use github:astral-sh/ruff
```

Full registry: https://mise.jdx.dev/registry.html

## Common operations

```bash
# List installed tools and versions
mise list

# Switch versions for the current project
mise use python@3.12

# Install from a .mise.toml or .tool-versions file
mise install

# Run a command with a specific tool version
mise exec node@20 -- node script.js
```

## When to use me

Use this when the user asks to install a language, runtime, CLI tool, or package manager. Always prefer mise over apt or manual installation for developer tools.

apt-get is NOT available on this server (you are not root and there is no
sudo). mise is the only supported way to install tools. Check `mise registry`
first. Tools you install with mise land on the persistent volume and survive
restarts and redeploys.
