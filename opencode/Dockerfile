FROM ghcr.io/anomalyco/opencode:latest

USER root

# Tools OpenCode/skills will commonly need.
RUN apk add --no-cache \
    bash \
    git \
    github-cli \
    openssh-client \
    nodejs \
    npm \
    ripgrep \
    curl \
    ca-certificates

# Create a predictable non-root home.
RUN addgroup -S -g 1000 opencode 2>/dev/null || true \
    && adduser -S -D -u 1000 -G opencode -h /home/opencode opencode 2>/dev/null || true \
    && mkdir -p \
        /home/opencode/.config/opencode \
        /home/opencode/.agents/skills \
        /home/opencode/.local/share \
        /home/opencode/.npm \
        /workspace \
    && chown -R opencode:opencode \
        /home/opencode \
        /workspace

USER opencode

ENV HOME=/home/opencode
ENV XDG_CONFIG_HOME=/home/opencode/.config
ENV XDG_DATA_HOME=/home/opencode/.local/share
ENV DISABLE_TELEMETRY=1

WORKDIR /workspace

EXPOSE 4096
EXPOSE 3333

CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]

