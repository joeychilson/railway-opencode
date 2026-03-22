FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV MISE_YES=1
ENV HOME=/var/lib/opencode
ENV MISE_DATA_DIR=/opt/mise-build
ENV MISE_GLOBAL_CONFIG_FILE=/opt/mise-build/.mise.toml
ENV PATH="/opt/mise-build/shims:/usr/local/bin:${PATH}"

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
    mkdir -p "$MISE_DATA_DIR" /workspace /opt/seed && \
    chown -R opencode:opencode "$HOME" "$MISE_DATA_DIR" /workspace /opt/seed && \
    chmod 0755 /usr/local/bin/entrypoint.sh

USER opencode
WORKDIR /workspace
SHELL ["/bin/bash", "-c"]

COPY --chown=opencode:opencode .mise.toml /opt/mise-build/.mise.toml
RUN mise install && \
    mise reshim && \
    npm install -g opencode-ai agent-browser && \
    mise reshim

COPY --chown=opencode:opencode skills/ skills/
RUN npx skills add railwayapp/railway-skills -a opencode -y && \
    npx skills add ./skills -a opencode -y && \
    rm -rf skills/ skills-lock.json

RUN cp -a /opt/mise-build /opt/seed/.mise && \
    cp -a /workspace/.agents /opt/seed/.agents

ENV MISE_DATA_DIR=/workspace/.mise
ENV MISE_GLOBAL_CONFIG_FILE=/workspace/.mise/.mise.toml
ENV PATH="/workspace/.mise/shims:/usr/local/bin:${PATH}"

ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
