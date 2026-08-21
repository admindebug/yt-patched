#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Downloads the latest MicroG-RE APK into WORK_DIR/microg.apk.
MICROG_REPO="${MICROG_REPO:-MorpheApp/MicroG-RE}"

# GitHub API calls need a token to avoid rate-limiting (esp. on shared runner IPs).
GH_API_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    GH_API_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

APK_URL=$(curl -fsSL "${GH_API_AUTH[@]}" "https://api.github.com/repos/$MICROG_REPO/releases/latest" \
    | grep -oE '"browser_download_url": "[^"]*\.apk"' | head -1 | sed -E 's/.*"([^"]*)"/\1/')
[ -n "$APK_URL" ] || fail "Cannot resolve MicroG release URL."

mkdir -p "$WORK_DIR"
[ -f "$WORK_DIR/microg.apk" ] || curl -fsSL --retry 3 -o "$WORK_DIR/microg.apk" "$APK_URL"

log "MicroG: $(basename "$APK_URL") -> $WORK_DIR/microg.apk"
