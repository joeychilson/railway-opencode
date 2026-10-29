# OpenCode server for Railway: a pinned opencode binary, mise-managed dev
# runtimes, preinstalled agent skills, and headless Chromium for browser
# automation.
#
# Layout:
#   /usr/local/bin/opencode   pinned binary, upgraded with the image
#   /opt/opencode/            baked config and image-managed skills
#   /var/lib/opencode ($HOME) runtime state; mount the Railway volume here
#   /opt/seed/                pristine copy of $HOME; the entrypoint copies it
#                             onto the volume on first boot and again whenever
#                             the seed stamp changes

# renovate: datasource=docker packageName=debian depName=Debian depType=tool
ARG DEBIAN_VERSION=trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

FROM debian:${DEBIAN_VERSION}

# renovate: datasource=npm packageName=@opencode/cli depName=OpenCode
ARG OPENCODE_VERSION=2.2.0
# renovate: datasource=github-releases packageName=jdx/mise depName=mise depType=tool
ARG MISE_VERSION=v2026.10.21

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

# mise falls back to compiling a new Python patch release until a prebuilt
# archive is available, so keep the CPython build dependencies in the image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    libffi-dev \
    liblzma-dev \
    uuid-dev \
    tk-dev \
    xz-utils \
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
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN curl -fsSL https://mise.run | MISE_VERSION=${MISE_VERSION} MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

RUN curl -fsSL https://opencode.ai/v2/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path \
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
    && npm install -g agent-browser corepack \
    && mise reshim \
    && node --version && python --version && bun --version && go version \
    && gh --version && railway --version && corepack --version \
    && agent-browser --help >/dev/null

# Skills installed at build time land in ~/.agents/skills; move them to the
# image-managed skills dir (listed under skills in opencode.json) so they
# upgrade with the image instead of going stale on the volume.
RUN npx -y skills add railwayapp/railway-skills -a opencode -y \
    && npx -y skills add vercel-labs/agent-browser -s agent-browser -a opencode -y \
    && npx -y skills add anthropics/skills -s skill-creator -s frontend-design -a opencode -y \
    && mv "$HOME"/.agents/skills/* /opt/opencode/skills/ \
    && rm -rf "$HOME"/.agents "$HOME"/skills-lock.json \
    && ls /opt/opencode/skills

# Slim down, then snapshot $HOME as the volume seed. This layer reruns
# whenever an earlier layer changed, so a fresh random stamp marks exactly
# the images whose seed may differ from what is on the volume.
RUN npm cache clean --force \
    && mise cache clear \
    && rm -rf "$HOME/.npm" "$HOME/.cache" \
    && cat /proc/sys/kernel/random/uuid > "$HOME/.seed-stamp" \
    && cp -a "$HOME"/. /opt/seed/

# The entrypoint starts as root to chown the Railway volume (mounted
# root-owned), then drops to the opencode user via gosu.
USER root

EXPOSE 4096
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 CMD ["healthcheck"]
ENTRYPOINT ["/usr/local/bin/entrypoint"]
