#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require java

CLI_FILE="$(cat "$WORK_DIR/.cli")"
PATCHES_FILE="$(cat "$WORK_DIR/.patches")"
STOCK_APK="${STOCK_APK:-$WORK_DIR/youtube-stock.apk}"
OUTPUT_APK="${OUTPUT_APK:-$WORK_DIR/youtube-patched.apk}"
KEYSTORE="${KEYSTORE:-$PROJECT_DIR/keystore/morphe.keystore}"

[ -f "$CLI_FILE" ]   || fail "CLI not found: $CLI_FILE"
[ -f "$PATCHES_FILE" ] || fail "Patches not found: $PATCHES_FILE"
[ -f "$STOCK_APK" ]  || fail "Stock APK not found: $STOCK_APK"

VERSION="$(read_json "['youtube_version']")"

# Build -e / -O argument list from config/patches.json
CONFIG_FILE="$CONFIG_FILE" python3 - > "$WORK_DIR/patch-args.txt" <<'EOF'
import json, os, sys
cfg = json.load(open(os.environ["CONFIG_FILE"]))
args = []
for p in cfg.get("patches", []):
    args.append("-e")
    args.append(p["name"])
    for key, value in p.get("options", {}).items():
        args.append(f"-O{key}={value}")
print("\n".join(args))
EOF

readarray -t ARGS < "$WORK_DIR/patch-args.txt"

KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-morphe}"
KEYSTORE_PASS="${KEYSTORE_PASS:-morphepass}"

# Ensure a keystore exists (alias kept lowercase for maximum compatibility)
if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$(dirname "$KEYSTORE")"
    keytool -genkey -v -keystore "$KEYSTORE" -alias "$KEYSTORE_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
        -dname "CN=Morphe, OU=RVX, O=RVX, L=RVX, ST=RVX, C=US" >/dev/null 2>&1
fi

log "Patching YouTube $VERSION with $((${#ARGS[@]} / 2)) patches..."
java -Xmx3g -jar "$CLI_FILE" patch \
    --continue-on-error --force --exclusive \
    -p "$PATCHES_FILE" \
    -o "$OUTPUT_APK" \
    "${ARGS[@]}" \
    --keystore="$KEYSTORE" \
    --keystore-entry-alias="$KEYSTORE_ALIAS" \
    --keystore-password="$KEYSTORE_PASS" \
    --keystore-entry-password="$KEYSTORE_PASS" \
    "$STOCK_APK" 2>&1 | tee "$WORK_DIR/patch.log"

[ -f "$OUTPUT_APK" ] || fail "Patching failed - no output APK produced."
log "Patched APK: $OUTPUT_APK"
