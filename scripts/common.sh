#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$PROJECT_DIR/work}"
OUT_DIR="${OUT_DIR:-$PROJECT_DIR/out}"
MODULE_DIR="${MODULE_DIR:-$PROJECT_DIR/module}"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/patches.json}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but not installed."; }

github_latest_release_url() {
    local repo="$1" pattern="$2"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oE '"browser_download_url": "[^"]*"' \
        | sed -E 's/.*"([^"]*)"/\1/' \
        | grep -E "$pattern" | head -1
}

read_json() {
    python3 -c "import json,sys; d=json.load(open('$CONFIG_FILE')); print(d$1)" 2>/dev/null \
        || fail "Cannot read '$CONFIG_FILE'"
}

clean_work() { rm -rf "$WORK_DIR" "$OUT_DIR" && mkdir -p "$WORK_DIR" "$OUT_DIR"; }
