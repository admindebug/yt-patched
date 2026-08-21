#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Full local build: fetch sources -> download APK -> patch -> build module
# -> copy to public storage -> notify Telegram.
#
# Usage:
#   ./scripts/build-local.sh                 # build version from config/patches.json
#   ./scripts/build-local.sh 20.51.39        # override version
#
# Needs: java, curl, zip, python3, keytool

require java && require curl && require zip && require python3

VERSION_OVERRIDE="${1:-}"
export WORK_DIR OUT_DIR GITHUB_REPOSITORY

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-admindebug/yt-patched}"
BUILD_START="$(date +%s)"

notify() { bash "$PROJECT_DIR/scripts/telegram.sh" "$1"; }

cleanup_fail() {
    notify "❌ <b>Build YouTube RVX GAGAL</b>
Step: <code>$1</code>
Log: <code>$PROJECT_DIR/work/patch.log</code> (jika ada)" || true
    exit 1
}

# 1. Version
if [ -n "$VERSION_OVERRIDE" ]; then
    bash "$PROJECT_DIR/scripts/set-version.sh" "$VERSION_OVERRIDE" || cleanup_fail "set-version"
fi
VERSION="$(read_json "['youtube_version']")"
log "Memulai build YouTube RVX v$VERSION"

# 2. Sources (Morphe CLI + patches Anddea .mpp)
bash "$PROJECT_DIR/scripts/fetch-sources.sh" || cleanup_fail "fetch-sources"

# 3. Stock APK
bash "$PROJECT_DIR/scripts/download-apk.sh" || cleanup_fail "download-apk"

# 4. MicroG (untuk dikirim ke Telegram)
bash "$PROJECT_DIR/scripts/fetch-microg.sh" || cleanup_fail "fetch-microg"

# 5. Patch (langkah terberat: ~30-50 menit)
bash "$PROJECT_DIR/scripts/patch-apk.sh" || cleanup_fail "patch-apk"

# 6. Build module zip
bash "$PROJECT_DIR/scripts/build-module.sh" || cleanup_fail "build-module"

source "$WORK_DIR/.module"
DURATION="$(( ($(date +%s) - BUILD_START) / 60 )) menit"

# 7. Salin ke storage publik agar mudah diambil
DEST_DIR="/sdcard/Download/YouTube-RVX"
if [ -d /sdcard ] && [ -w /sdcard ]; then
    mkdir -p "$DEST_DIR"
    cp "$MODULE_ZIP" "$DEST_DIR/YTPatched_ROOT-$VERSION.zip"
    cp "$WORK_DIR/youtube-patched.apk" "$DEST_DIR/YTPatched_NON_ROOT-$VERSION.apk" 2>/dev/null || true
    cp "$WORK_DIR/youtube-cloned.apk" "$DEST_DIR/YTPatched_CLONE-$VERSION.apk" 2>/dev/null || true
    cp "$WORK_DIR/microg.apk" "$DEST_DIR/MicroG.apk" 2>/dev/null || true
    log "File juga tersedia di: $DEST_DIR"
    DEST_NOTE="📂 <b>Lokasi file di device:</b> <code>$DEST_DIR</code>"
else
    DEST_NOTE="📂 <b>Lokasi file:</b> <code>$OUT_DIR</code>"
fi

# 8. Kirim ke Telegram (akun user via STRING_SESSION - sekali kirim tanpa split)
bash "$PROJECT_DIR/scripts/telegram.sh" || { echo "Telegram gagal."; exit 1; }
bash "$PROJECT_DIR/scripts/telegram.sh" "⏱️ Waktu build: <b>$DURATION</b>
$DEST_NOTE
🔗 Repo: <a href=\"https://github.com/$GITHUB_REPOSITORY\">$GITHUB_REPOSITORY</a>" || true

log "Selesai! Module: $MODULE_ZIP ($DURATION)"
