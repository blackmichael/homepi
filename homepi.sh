#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="proxy_external"
INFRASTRUCTURE_APP="infrastructure"
INFRASTRUCTURE_RUNTIME_DIR=".runtime"
INFRASTRUCTURE_CREDENTIALS_FILE="tunnel-credentials.json"

# Auto-discover apps: directories containing a docker-compose.yml
discover_apps() {
    local apps=()
    for dir in "$SCRIPT_DIR"/*/; do
        if [[ -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]]; then
            apps+=("$(basename "$dir")")
        fi
    done
    echo "${apps[@]}"
}

ALL_APPS=($(discover_apps))

compose_file_for_app() {
    local app="$1"
    local compose_dir="$SCRIPT_DIR/$app"

    if [[ -f "$compose_dir/docker-compose.yml" ]]; then
        echo "$compose_dir/docker-compose.yml"
    elif [[ -f "$compose_dir/docker-compose.yaml" ]]; then
        echo "$compose_dir/docker-compose.yaml"
    else
        return 1
    fi
}

prepare_runtime_secrets() {
    local app="$1"
    local compose_dir="$2"
    local env_template="$3"

    if [[ "$app" != "$INFRASTRUCTURE_APP" ]]; then
        return 0
    fi

    local runtime_dir="$compose_dir/$INFRASTRUCTURE_RUNTIME_DIR"
    local credentials_file="$runtime_dir/$INFRASTRUCTURE_CREDENTIALS_FILE"

    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"

    if [[ "$NO_SECRETS" == "true" ]]; then
        if [[ ! -f "$credentials_file" ]]; then
            echo "Error: missing $credentials_file. Start without --no-secrets or create runtime credentials file first." >&2
            return 1
        fi
        return 0
    fi

    if [[ -z "$env_template" ]]; then
        echo "Error: $app requires $compose_dir/.env.template to load tunnel credentials." >&2
        return 1
    fi

    if ! command -v op >/dev/null 2>&1; then
        echo "Error: 1Password CLI ('op') is required to load secrets for $app." >&2
        return 1
    fi

    op run --env-file "$env_template" -- /bin/sh -c '
        if [ -z "${CLOUDFLARED_TUNNEL_CREDENTIALS_JSON:-}" ]; then
            echo "Error: CLOUDFLARED_TUNNEL_CREDENTIALS_JSON is not set." >&2
            exit 1
        fi

        umask 077
        printf "%s" "$CLOUDFLARED_TUNNEL_CREDENTIALS_JSON" > "$1"
    ' sh "$credentials_file"
}

cleanup_runtime_secrets() {
    local app="$1"
    local compose_dir="$2"

    if [[ "$app" != "$INFRASTRUCTURE_APP" ]]; then
        return 0
    fi

    local runtime_dir="$compose_dir/$INFRASTRUCTURE_RUNTIME_DIR"
    local credentials_file="$runtime_dir/$INFRASTRUCTURE_CREDENTIALS_FILE"

    rm -f "$credentials_file"
    rmdir "$runtime_dir" 2>/dev/null || true
}

run_compose_up() {
    local compose_file="$1"
    local env_template="$2"
    local pull="$3"

    local cmd=(docker compose)
    if [[ -n "$env_template" && "$NO_SECRETS" == "true" ]]; then
        cmd+=(--env-file "$env_template")
    fi
    cmd+=(-f "$compose_file" up -d)

    if [[ "$pull" == "true" ]]; then
        cmd+=(--pull always)
    fi

    if [[ -n "$env_template" && "$NO_SECRETS" == "false" ]]; then
        if ! command -v op >/dev/null 2>&1; then
            echo "Error: 1Password CLI ('op') is required to load secrets for $(basename "$(dirname "$compose_file")")." >&2
            return 1
        fi

        op run --env-file "$env_template" -- "${cmd[@]}"
        return
    fi

    "${cmd[@]}"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Manage homepi docker compose services.

Options:
  --start          Start specified apps
  --stop           Stop specified apps
  --pull           Pull latest images before starting
  --no-secrets     Skip loading variables through 1Password
  --app <apps>     Space-separated list of app names, or "all"
                   Available apps: ${ALL_APPS[*]}
  -h, --help       Show this help message

Examples:
  $(basename "$0") --start --app all
  $(basename "$0") --start --app infrastructure simple-web --pull
  $(basename "$0") --start --app infrastructure --no-secrets
  $(basename "$0") --stop --app bluesky-api
  $(basename "$0") --stop --app all
EOF
}

ensure_network() {
    if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
        echo "Creating docker network '$NETWORK_NAME'..."
        docker network create "$NETWORK_NAME"
    fi
}

remove_network() {
    if docker network inspect "$NETWORK_NAME" &>/dev/null; then
        echo "Removing docker network '$NETWORK_NAME'..."
        docker network rm "$NETWORK_NAME"
    fi
}

start_app() {
    local app="$1"
    local pull="$2"
    local compose_dir="$SCRIPT_DIR/$app"
    local env_template=""
    local compose_file

    if [[ ! -d "$compose_dir" ]]; then
        echo "Error: app directory '$app' not found" >&2
        return 1
    fi

    if ! compose_file="$(compose_file_for_app "$app")"; then
        echo "Error: docker compose file for '$app' not found" >&2
        return 1
    fi

    if [[ -f "$compose_dir/.env.template" ]]; then
        env_template="$compose_dir/.env.template"
    fi

    echo "Starting $app..."
    prepare_runtime_secrets "$app" "$compose_dir" "$env_template"
    run_compose_up "$compose_file" "$env_template" "$pull"
}

stop_app() {
    local app="$1"
    local compose_dir="$SCRIPT_DIR/$app"
    local env_template=""
    local compose_file

    if [[ ! -d "$compose_dir" ]]; then
        echo "Error: app directory '$app' not found" >&2
        return 1
    fi

    if ! compose_file="$(compose_file_for_app "$app")"; then
        echo "Error: docker compose file for '$app' not found" >&2
        return 1
    fi

    if [[ -f "$compose_dir/.env.template" ]]; then
        env_template="$compose_dir/.env.template"
    fi

    echo "Stopping $app..."
    if [[ -n "$env_template" ]]; then
        docker compose --env-file "$env_template" -f "$compose_file" down
    else
        docker compose -f "$compose_file" down
    fi
    cleanup_runtime_secrets "$app" "$compose_dir"
}

# Parse arguments
ACTION=""
APPS=()
PULL="false"
NO_SECRETS="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start)
            ACTION="start"
            shift
            ;;
        --stop)
            ACTION="stop"
            shift
            ;;
        --pull)
            PULL="true"
            shift
            ;;
        --no-secrets)
            NO_SECRETS="true"
            shift
            ;;
        --app)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                APPS+=("$1")
                shift
            done
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$ACTION" ]]; then
    echo "Error: must specify --start or --stop" >&2
    usage
    exit 1
fi

if [[ ${#APPS[@]} -eq 0 ]]; then
    echo "Error: must specify --app" >&2
    usage
    exit 1
fi

# Expand "all"
if [[ ${#APPS[@]} -eq 1 && "${APPS[0]}" == "all" ]]; then
    APPS=("${ALL_APPS[@]}")
    IS_ALL="true"
else
    IS_ALL="false"
fi

# Validate app names
for app in "${APPS[@]}"; do
    found="false"
    for valid in "${ALL_APPS[@]}"; do
        if [[ "$app" == "$valid" ]]; then
            found="true"
            break
        fi
    done
    if [[ "$found" == "false" ]]; then
        echo "Error: unknown app '$app'. Available: ${ALL_APPS[*]}" >&2
        exit 1
    fi
done

# Execute
if [[ "$ACTION" == "start" ]]; then
    ensure_network
    for app in "${APPS[@]}"; do
        start_app "$app" "$PULL"
    done
    echo "Done."
elif [[ "$ACTION" == "stop" ]]; then
    for app in "${APPS[@]}"; do
        stop_app "$app"
    done
    if [[ "$IS_ALL" == "true" ]]; then
        remove_network
    fi
    echo "Done."
fi
