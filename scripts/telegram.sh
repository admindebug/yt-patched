#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require python3

# Upload build ke Telegram.
# Mode utama: akun user via Telethon (TELEGRAM_STRING_SESSION) - tanpa split.
# Fallback  : Bot API (TELEGRAM_BOT_TOKEN) - batas 50 MB.
# Logika lengkap ada di telegram_upload.py.
exec python3 "$PROJECT_DIR/scripts/telegram_upload.py" "$@"
