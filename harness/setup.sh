#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_DIR="/mnt/data/dev/paseo"
PASEO_HOME="$PASEO_DIR/home"
SSH_DIR="$PASEO_HOME/.ssh"
PASEO_STATE_DIR="$PASEO_HOME/.paseo"
SSH_KEY="/mnt/data/dev/ssh/id_ed25519"
KNOWN_HOSTS_SOURCE="${KNOWN_HOSTS_SOURCE:-${HOME:-/root}/.ssh/known_hosts}"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Error: expected GitHub SSH key at $SSH_KEY" >&2
    exit 1
fi

mkdir -p "$SSH_DIR" "$PASEO_STATE_DIR"

CONFIG_FILE="$PASEO_STATE_DIR/config.json"
if [[ ! -e "$CONFIG_FILE" ]]; then
    install -m 600 "$SCRIPT_DIR/config.json" "$CONFIG_FILE"
else
    echo "Keeping existing Paseo config: $CONFIG_FILE"
fi

KNOWN_HOSTS_FILE="$SSH_DIR/known_hosts"
if [[ ! -e "$KNOWN_HOSTS_FILE" && -f "$KNOWN_HOSTS_SOURCE" ]]; then
    install -m 644 "$KNOWN_HOSTS_SOURCE" "$KNOWN_HOSTS_FILE"
elif [[ ! -e "$KNOWN_HOSTS_FILE" ]]; then
    echo "Warning: no known_hosts file found at $KNOWN_HOSTS_SOURCE; SSH may prompt to trust GitHub." >&2
fi

chmod 700 "$SSH_DIR"

# Paseo runs as uid/gid 1000 in the container. Keep its persisted files writable.
if [[ "$(id -u)" == "0" ]]; then
    chown -R 1000:1000 "$PASEO_DIR"
elif [[ "$(id -u):$(id -g)" != "1000:1000" ]]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R 1000:1000 "$PASEO_DIR"
    else
        echo "Error: run 'chown -R 1000:1000 $PASEO_DIR' to match the container user." >&2
        exit 1
    fi
fi

echo "Paseo directories and OMP provider config are ready under $PASEO_HOME."
echo "Start the service from the repository root with: sudo ops -- ./homepi.sh --start --app harness"
