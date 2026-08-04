#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require curl

# Sends the build result to a Telegram channel.
# - If the module zip is <= 50 MB (Telegram bot limit) it is uploaded directly.
# - Otherwise a message with the GitHub release link + summary is sent.
# Credentials MUST come from environment / GitHub Secrets, never hardcoded.
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHANNEL_ID" ]; then
    log "TELEGRAM_BOT_TOKEN / TELEGRAM_CHANNEL_ID not set - skipping Telegram upload."
    exit 0
fi

[ -f "$WORK_DIR/.module" ] || fail "No module info found - run build-module.sh first."
source "$WORK_DIR/.module"

VERSION="$(read_json "['youtube_version']")"
REPO="${GITHUB_REPOSITORY:-local/local}"
RELEASE_URL="https://github.com/$REPO/releases/tag/v$VERSION"
CHANGELOG_URL="https://raw.githubusercontent.com/$REPO/main/changelog.md"

# Build a compact summary from the patch config
SUMMARY="$(python3 - "$CONFIG_FILE" <<'EOF'
import json, os, sys
cfg = json.load(open(os.environ.get("CONFIG_FILE", sys.argv[1])))
names = [p["name"] for p in cfg.get("patches", [])]
highlights = []
for kw in ("Hide ads", "Background playback", "Spoof video", "SponsorBlock",
           "Return YouTube Dislike", "Miniplayer"):
    hit = next((n for n in names if kw.lower() in n.lower()), None)
    if hit:
        highlights.append(hit)
if not highlights:
    highlights = names[:4]
print("\n".join(f"• {h}" for h in highlights))
EOF
)"

API="https://api.telegram.org/bot${BOT_TOKEN}"
SIZE="$(stat -c %s "$MODULE_ZIP")"

# Build the caption/message (HTML parse mode is more forgiving than Markdown)
build_text() {
    cat <<EOF
<b>📺 YouTube ReVanced Extended v${VERSION}</b>

✅ Module berhasil di-build otomatis!
🔗 Release: ${RELEASE_URL}

<b>Patch:</b>
${SUMMARY}

<b>📥 Install:</b> download zip di Release, lalu flash via Magisk / KSU / Apatch.
<a href="${CHANGELOG_URL}">📜 Changelog</a>
EOF
}

if [ "$SIZE" -le 52428800 ]; then
    curl -fsSL -F "chat_id=$CHANNEL_ID" \
        -F "document=@$MODULE_ZIP" \
        -F "caption=$(build_text)" \
        -F "parse_mode=HTML" \
        "$API/sendDocument" >/dev/null \
        && log "Sent $MODULE_NAME to Telegram channel $CHANNEL_ID" \
        || { echo "Telegram send failed (check BOT_TOKEN / CHANNEL_ID)."; exit 1; }
else
    log "Module is $(du -h "$MODULE_ZIP" | cut -f1) (>50MB bot limit) - sending release link instead."
    curl -fsSL -F "chat_id=$CHANNEL_ID" \
        -F "text=$(build_text)" \
        -F "parse_mode=HTML" \
        "$API/sendMessage" >/dev/null \
        && log "Sent release link to Telegram channel $CHANNEL_ID" \
        || { echo "Telegram send failed (check BOT_TOKEN / CHANNEL_ID)."; exit 1; }
fi
