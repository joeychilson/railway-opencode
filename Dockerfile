# syntax=docker/dockerfile:1

# OpenCode server for Railway: a pinned opencode binary, mise-managed dev
# runtimes, preinstalled agent skills, and headless Chromium for browser
# automation.
#
# Layout:
#   /usr/local/bin/opencode   pinned binary — upgrades with the image
#   /opt/opencode/            baked config + image-managed skills
#   /var/lib/opencode ($HOME) runtime state — mount the Railway volume here
#   /opt/seed/                pristine copy of $HOME; the entrypoint populates
#                             the volume from it on first boot and re-syncs
#                             image-managed files when the seed stamp changes

FROM debian:bookworm-slim

# Version pins — bump these to upgrade:
ARG OPENCODE_VERSION=1.18.3
ARG MISE_VERSION=v2026.7.6
# Changing the stamp makes existing volumes re-sync image-managed files
# (mise tools, default mise config, .bashrc) on next boot. CI sets it to the
# git SHA so every published image refreshes the seed.
ARG SEED_STAMP=opencode-${OPENCODE_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/var/lib/opencode \
    MISE_DATA_DIR=/var/lib/opencode/.mise \
    MISE_YES=1 \
    MISE_USE_VERSIONS_HOST_TRACK=false \
    OPENCODE_CONFIG=/opt/opencode/opencode.json \
    OPENCODE_DISABLE_AUTOUPDATE=1 \
    CHROME_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROMIUM_PATH=/usr/bin/chromium \
    PATH=/var/lib/opencode/.mise/shims:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    gosu \
    jq \
    ripgrep \
    unzip \
    zip \
    less \
    procps \
    openssh-client \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libcups2 \
    libxkbcommon0 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -fsSL https://mise.run | MISE_VERSION=${MISE_VERSION} MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

RUN curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path \
    && install -m 0755 "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode \
    && rm -rf "$HOME/.opencode" \
    && opencode --version | grep -F "${OPENCODE_VERSION}"

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint
COPY --chmod=755 healthcheck.sh /usr/local/bin/healthcheck

RUN mkdir -p "$HOME" /opt/seed /opt/opencode/skills \
    && useradd -d "$HOME" -s /bin/bash opencode \
    && chown -R opencode:opencode "$HOME" /opt/seed /opt/opencode

COPY --chown=opencode:opencode opencode.json /opt/opencode/opencode.json
COPY --chown=opencode:opencode workspace/AGENTS.md /opt/opencode/AGENTS.md
COPY --chown=opencode:opencode skills/ /opt/opencode/skills/

USER opencode
WORKDIR $HOME

COPY --chown=opencode:opencode mise.toml $HOME/.config/mise/config.toml

RUN echo 'eval "$(mise activate bash)"' >> "$HOME/.bashrc" \
    && mise install \
    && mise reshim \
    && npm install -g agent-browser \
    && mise reshim \
    && node --version && python --version && bun --version && go version \
    && gh --version && railway --version && agent-browser --help >/dev/null

# Skills installed at build time land in ~/.agents/skills; move them to the
# image-managed skills dir (referenced by opencode.json skills.paths) so they
# upgrade with the image instead of going stale on the volume.
RUN npx -y skills add railwayapp/railway-skills -a opencode -y \
    && npx -y skills add vercel-labs/agent-browser -s agent-browser -a opencode -y \
    && npx -y skills add anthropics/skills -s skill-creator -s frontend-design -a opencode -y \
    && mv "$HOME"/.agents/skills/* /opt/opencode/skills/ \
    && rm -rf "$HOME"/.agents "$HOME"/skills-lock.json \
    && ls /opt/opencode/skills

# Slim down, then snapshot $HOME as the volume seed.
RUN npm cache clean --force \
    && mise cache clear \
    && rm -rf "$HOME/.npm" "$HOME/.cache" \
    && printf '%s\n' "${SEED_STAMP}" > "$HOME/.seed-stamp" \
    && cp -a "$HOME"/. /opt/seed/

# The entrypoint starts as root to chown the Railway volume (mounted
# root-owned), then drops to the opencode user via gosu.
USER root

EXPOSE 4096
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 CMD ["healthcheck"]
ENTRYPOINT ["/usr/local/bin/entrypoint"]
