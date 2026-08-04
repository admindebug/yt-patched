#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require python3

# Optional override: ./scripts/download-apk.sh <version> [output.apk]
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(read_json "['youtube_version']")"
fi
OUTPUT="${2:-$WORK_DIR/youtube-stock.apk}"

mkdir -p "$(dirname "$OUTPUT")"
log "Downloading YouTube $VERSION base APK from APKMirror..."
python3 "$PROJECT_DIR/scripts/download_apk.py" "$VERSION" "$OUTPUT"
[ -f "$OUTPUT" ] || fail "APK download failed."
