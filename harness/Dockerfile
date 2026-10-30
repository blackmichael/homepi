FROM ghcr.io/getpaseo/paseo:latest

USER root

# Development tools commonly needed by OMP and agent skills.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        gh \
        openssh-client \
        ripgrep \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Keep npm's cache out of the persistent /home/paseo bind mount. The container
# starts as root, then runs agent processes as uid 1000; sharing that cache can
# leave root-owned entries that newer npm versions reject.
ENV NPM_CONFIG_CACHE=/tmp/npm-cache

# Paseo's base image includes Node/npm. OMP's CLI has a Bun shebang and
# requires Bun at runtime, so install the current npm and both global binaries.
RUN npm install -g npm@latest \
    && npm install -g bun @oh-my-pi/pi-coding-agent \
    && node --version \
    && npm --version \
    && bun --version \
    && omp --version

# Keep root as the entrypoint user: Paseo normalizes mounted-volume ownership,
# then drops the daemon and agent processes to its non-root paseo user (uid 1000).
WORKDIR /workspace
