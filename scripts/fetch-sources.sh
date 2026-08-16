#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Downloads the latest Morphe CLI and Anddea patches (.mpp) into WORK_DIR.
MORPHE_REPO="${MORPHE_REPO:-MorpheApp/morphe-cli}"
ANDDEA_REPO="${ANDDEA_REPO:-anddea/revanced-patches}"

# GitHub API calls need a token to avoid rate-limiting (esp. on shared runner IPs).
GH_API_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    GH_API_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

api_get() {
    curl -fsSL "${GH_API_AUTH[@]}" "https://api.github.com/repos/$1/releases/latest"
}

# Resolve Morphe CLI latest release (morphe-cli redirects to morphe-desktop assets)
CLI_URL=$(api_get "$MORPHE_REPO" \
    | grep -oE '"browser_download_url": "[^"]*all\.jar"' | head -1 | sed -E 's/.*"([^"]*)"/\1/')
[ -n "$CLI_URL" ] || fail "Cannot resolve Morphe CLI release URL."
CLI_FILE="$(basename "$CLI_URL")"
log "Morphe CLI: $CLI_FILE"

# Resolve Anddea patches latest .mpp
PATCHES_URL=$(api_get "$ANDDEA_REPO" \
    | grep -oE '"browser_download_url": "[^"]*\.mpp"' | head -1 | sed -E 's/.*"([^"]*)"/\1/')
[ -n "$PATCHES_URL" ] || fail "Cannot resolve Anddea patches release URL."
PATCHES_FILE="$(basename "$PATCHES_URL")"
log "Anddea patches: $PATCHES_FILE"

mkdir -p "$WORK_DIR"

[ -f "$WORK_DIR/$CLI_FILE" ] || curl -fsSL --retry 3 -o "$WORK_DIR/$CLI_FILE" "$CLI_URL"
[ -f "$WORK_DIR/$PATCHES_FILE" ] || curl -fsSL --retry 3 -o "$WORK_DIR/$PATCHES_FILE" "$PATCHES_URL"

# Persist resolved paths for later steps
echo "$WORK_DIR/$CLI_FILE"    > "$WORK_DIR/.cli"
echo "$WORK_DIR/$PATCHES_FILE" > "$WORK_DIR/.patches"
echo "cli=$CLI_FILE"          > "$WORK_DIR/manifest.txt"
echo "patches=$PATCHES_FILE"  >> "$WORK_DIR/manifest.txt"

log "Sources ready."
