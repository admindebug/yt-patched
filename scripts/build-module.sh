#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require zip

VERSION="$(read_json "['youtube_version']")"
STOCK_APK="${STOCK_APK:-$WORK_DIR/youtube-stock.apk}"
PATCHED_APK="${PATCHED_APK:-$WORK_DIR/youtube-patched.apk}"
MODULE_NAME="YouTube.RVX.v$VERSION.zip"
MODULE_ZIP="$OUT_DIR/$MODULE_NAME"

[ -f "$STOCK_APK" ]   || fail "Stock APK missing: $STOCK_APK"
[ -f "$PATCHED_APK" ] || fail "Patched APK missing: $PATCHED_APK"

REPO="${GITHUB_REPOSITORY:-local/local}"
BUILD_CODE="${BUILD_CODE:-$(date +%Y%m%d%H%M)}"

mkdir -p "$OUT_DIR"
STAGE="$WORK_DIR/stage"
rm -rf "$STAGE" && mkdir -p "$STAGE/youtube"

# Module scripts + metadata
cp "$MODULE_DIR/customize.sh" "$STAGE/"
cp "$MODULE_DIR/service.sh"   "$STAGE/"
cp "$MODULE_DIR/uninstall.sh" "$STAGE/"
cp -r "$MODULE_DIR/META-INF"  "$STAGE/"

# module.prop
cat > "$STAGE/module.prop" <<EOF
id=YouTube-RVX
name=YouTube ReVanced Extended
version=v$VERSION
versionCode=$BUILD_CODE
author=$(jq -r '.author // "build"' "$CONFIG_FILE" 2>/dev/null || echo "build")
description=Patched YouTube module - ad-free with premium features
updateJson=https://raw.githubusercontent.com/$REPO/main/update.json
EOF

# update.json + changelog for in-module metadata / Magisk update
python3 - "$REPO" "$VERSION" "$BUILD_CODE" "$MODULE_NAME" > "$STAGE/update.json" <<'EOF'
import json, sys
repo, version, code, name = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
print(json.dumps({
    "version": f"v{version}",
    "versionCode": code,
    "zipUrl": f"https://github.com/{repo}/releases/download/v{version}/YouTube.RVX.v{version}.zip",
    "changelog": f"https://raw.githubusercontent.com/{repo}/main/changelog.md",
    "releaseType": "stable"
}, indent=2))
EOF

# APKs: stock goes to youtube/ (installed by customize.sh), patched at module root
cp "$STOCK_APK" "$STAGE/youtube/base.apk"
cp "$PATCHED_APK" "$STAGE/YouTubeRevanced-$VERSION.apk"

# Readme/changelog (optional; harmless inside module)
[ -f "$PROJECT_DIR/changelog.md" ] && cp "$PROJECT_DIR/changelog.md" "$STAGE/"

rm -f "$MODULE_ZIP"
( cd "$STAGE" && zip -q -r -X "$MODULE_ZIP" . )
[ -f "$MODULE_ZIP" ] || fail "Zip creation failed."

echo "MODULE_ZIP=$MODULE_ZIP"  > "$WORK_DIR/.module"
echo "MODULE_NAME=$MODULE_NAME" >> "$WORK_DIR/.module"
log "Module built: $MODULE_ZIP ($(du -h "$MODULE_ZIP" | cut -f1))"
