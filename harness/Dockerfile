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

# Paseo's base image includes Node/npm. OMP's CLI has a Bun shebang and
# requires Bun at runtime, so install both global binaries in the image.
RUN npm install -g bun @oh-my-pi/pi-coding-agent \
    && bun --version \
    && omp --version

# Keep root as the entrypoint user: Paseo normalizes mounted-volume ownership,
# then drops the daemon and agent processes to its non-root paseo user (uid 1000).
WORKDIR /workspace
