#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGETS_FILE="$REPO_DIR/.github/deploy-targets.txt"

usage() {
    cat <<EOF >&2
Usage: $(basename "$0") (--app <app> | --source-repo <owner/repo>)
EOF
    exit 1
}

MODE=""
VALUE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            [[ $# -ge 2 ]] || usage
            MODE="app"
            VALUE="$2"
            shift 2
            ;;
        --source-repo)
            [[ $# -ge 2 ]] || usage
            MODE="source_repo"
            VALUE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[[ -n "$MODE" && -n "$VALUE" ]] || usage
[[ -f "$TARGETS_FILE" ]] || {
    echo "Deploy targets file not found: $TARGETS_FILE" >&2
    exit 1
}

match_count=0
resolved_app=""
resolved_source_repo=""

while IFS='|' read -r app source_repo extra; do
    [[ -z "$app" || "$app" == \#* ]] && continue

    if [[ -n "$extra" || -z "$source_repo" ]]; then
        echo "Malformed deploy target entry: $app|$source_repo${extra:+|$extra}" >&2
        exit 1
    fi

    if [[ "$MODE" == "app" && "$app" == "$VALUE" ]]; then
        match_count=$((match_count + 1))
        resolved_app="$app"
        resolved_source_repo="$source_repo"
    fi

    if [[ "$MODE" == "source_repo" && "$source_repo" == "$VALUE" ]]; then
        match_count=$((match_count + 1))
        resolved_app="$app"
        resolved_source_repo="$source_repo"
    fi
done < "$TARGETS_FILE"

if [[ "$match_count" -eq 0 ]]; then
    if [[ "$MODE" == "app" ]]; then
        echo "Unsupported app: $VALUE" >&2
    else
        echo "Unsupported source repo: $VALUE" >&2
    fi
    exit 1
fi

if [[ "$match_count" -gt 1 ]]; then
    if [[ "$MODE" == "app" ]]; then
        echo "Duplicate app mapping found: $VALUE" >&2
    else
        echo "Duplicate source repo mapping found: $VALUE" >&2
    fi
    exit 1
fi

printf 'app=%s\n' "$resolved_app"
printf 'source_repo=%s\n' "$resolved_source_repo"
