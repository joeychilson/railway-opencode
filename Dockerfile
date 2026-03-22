FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_YES=1
ENV HOME=/var/lib/opencode
ENV MISE_DATA_DIR=/var/lib/opencode/.mise
ENV MISE_GLOBAL_CONFIG_FILE=/var/lib/opencode/.mise/.mise.toml
ENV PATH="/var/lib/opencode/.mise/shims:/usr/local/bin:${PATH}"

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

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN curl https://mise.run | sh && \
    install -m 0755 /var/lib/opencode/.local/bin/mise /usr/local/bin/mise && \
    useradd -m -d "$HOME" -s /bin/bash opencode && \
    mkdir -p "$MISE_DATA_DIR" /opt/seed && \
    chown -R opencode:opencode "$HOME" /opt/seed && \
    chmod 0755 /usr/local/bin/entrypoint.sh

USER opencode
WORKDIR $HOME
SHELL ["/bin/bash", "-c"]

COPY --chown=opencode:opencode .mise.toml $MISE_GLOBAL_CONFIG_FILE
RUN mise install && \
    mise reshim && \
    npm install -g opencode-ai agent-browser && \
    mise reshim

COPY --chown=opencode:opencode skills/ /tmp/skills/
RUN npx skills add railwayapp/railway-skills -a opencode -y && \
    npx skills add vercel-labs/agent-browser -s agent-browser -a opencode -y && \
    npx skills add anthropics/skills -s skill-creator -s frontend-design -a opencode -y && \
    npx skills add /tmp/skills -a opencode -y && \
    rm -rf /tmp/skills skills-lock.json

RUN cp -a $HOME/. /opt/seed/

ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
