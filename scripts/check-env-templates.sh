#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

MODE="worktree"
if [[ "${1:-}" == "--staged" ]]; then
    MODE="staged"
    shift
elif [[ "${1:-}" == "--worktree" ]]; then
    shift
fi

FILES=()
if [[ "$MODE" == "staged" ]]; then
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            FILES+=("$file")
        fi
    done < <(git diff --cached --name-only --diff-filter=ACMR -- '*.env.template')
else
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            FILES+=("$file")
        fi
    done < <(git ls-files '*.env.template')
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    exit 0
fi

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

key_is_secret_like() {
    local key="$1"

    if [[ "$key" =~ (^|_)PUBLIC(_|$) ]]; then
        return 1
    fi

    [[ "$key" =~ (^|_)(SECRET|TOKEN|PASSWORD|PASS|KEY|CREDENTIAL|CREDENTIALS|PRIVATE|AUTH)(_|$) ]]
}

value_is_allowed() {
    local value="$1"
    local lower_value
    lower_value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"

    if [[ -z "$value" ]]; then
        return 0
    fi

    if [[ "$value" =~ ^op:// ]]; then
        return 0
    fi

    if [[ "$value" =~ ^\$\{[A-Za-z_][A-Za-z0-9_]*\}$ ]]; then
        return 0
    fi

    if [[ "$value" == \<*\> ]]; then
        return 0
    fi

    [[ "$lower_value" =~ replace|example|changeme|placeholder|dummy|sample|todo|tbd ]]
}

scan_stream() {
    local file="$1"
    local line_number=0
    local failed=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number += 1))

        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
            continue
        fi

        if [[ "$line" != *=* ]]; then
            continue
        fi

        local key="${line%%=*}"
        local value="${line#*=}"

        key="$(trim "$key")"
        value="$(trim "$value")"

        if [[ -z "$key" ]]; then
            continue
        fi

        if [[ ${#value} -ge 2 ]]; then
            if [[ "$value" == '"'*'"' ]]; then
                value="${value#\"}"
                value="${value%\"}"
            elif [[ "$value" == "'"*"'" ]]; then
                value="${value#\'}"
                value="${value%\'}"
            fi
        fi

        if key_is_secret_like "$key" && ! value_is_allowed "$value"; then
            echo "Secret scan blocked: suspicious plaintext value in $file:$line_number for $key" >&2
            echo "Use 1Password secret reference, placeholder, or empty value in .env.template files." >&2
            failed=1
        fi
    done

    return "$failed"
}

for file in "${FILES[@]}"; do
    if [[ "$MODE" == "staged" ]]; then
        git show ":$file" | scan_stream "$file"
    else
        scan_stream "$file" < "$file"
    fi
done
