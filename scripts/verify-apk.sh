#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Verifikasi integritas hasil build sebelum dipublikasikan:
# - APK (patched & clone) diverifikasi tandanyaannya dengan apksigner
# - Module zip diuji struktur arsipnya dengan unzip -t
# Kalau apksigner tidak tersedia (mis. di Termux tanpa Android SDK),
# verifikasi dilewati dengan aman.

APKS=("$WORK_DIR/youtube-patched.apk")
[ -f "$WORK_DIR/youtube-cloned.apk" ] && APKS+=("$WORK_DIR/youtube-cloned.apk")

APKSIGNER="$(find "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/lib/android-sdk}}/build-tools" \
    -name apksigner 2>/dev/null | sort -V | tail -1)"

if [ -z "$APKSIGNER" ]; then
    log "apksigner tidak ditemukan - verifikasi tanda tangan dilewati."
else
    for APK in "${APKS[@]}"; do
        [ -f "$APK" ] || continue
        log "Verifikasi tanda tangan $(basename "$APK")..."
        "$APKSIGNER" verify --print-certs "$APK" >"$WORK_DIR/verify-$(basename "$APK").txt" 2>&1 \
            || fail "Verifikasi gagal, APK tidak valid: $APK"
        grep -m1 "^Signer" "$WORK_DIR/verify-$(basename "$APK").txt" || true
    done
    log "Semua APK valid."
fi

MODULE_ZIP="$(sed -n 's/^MODULE_ZIP=//p' "$WORK_DIR/.module" 2>/dev/null || true)"
if [ -n "$MODULE_ZIP" ] && [ -f "$MODULE_ZIP" ]; then
    unzip -tqq "$MODULE_ZIP" >/dev/null || fail "Module zip korup: $MODULE_ZIP"
    log "Module zip OK: $(basename "$MODULE_ZIP")"
fi
