FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_YES=1
ENV HOME=/var/lib/opencode
ENV MISE_DATA_DIR=/opt/mise
ENV PATH="/opt/mise/shims:/usr/local/bin:${PATH}"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
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

# Entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Install mise outside the user home so Railway volumes do not hide it
RUN curl https://mise.run | sh && \
    install -m 0755 "$HOME/.local/bin/mise" /usr/local/bin/mise && \
    useradd -m -d "$HOME" -s /bin/bash opencode && \
    mkdir -p "$MISE_DATA_DIR" /workspace /opt/skills-seed && \
    chown -R opencode:opencode "$HOME" "$MISE_DATA_DIR" /workspace /opt/skills-seed && \
    chmod 0755 /usr/local/bin/entrypoint.sh

USER opencode
WORKDIR /workspace
SHELL ["/bin/bash", "-c"]

# Copy tool config and install runtimes
COPY --chown=opencode:opencode .mise.toml .mise.toml
RUN mise install && \
    mise reshim && \
    npm install -g opencode-ai agent-browser && \
    mise reshim

# Copy custom skills source
COPY --chown=opencode:opencode skills/ skills/

# Install all skills (opencode agent only)
RUN npx skills add railwayapp/railway-skills -a opencode -y && \
    npx skills add ./skills -a opencode -y && \
    rm -rf skills/ skills-lock.json && \
    cp -a "$HOME/.agents" /opt/skills-seed

ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
