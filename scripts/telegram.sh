#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require curl

# Sends the build result to a Telegram channel.
# - Module zip <= 50 MB  -> uploaded directly as a document.
# - Module zip >  50 MB  -> split into <=48 MB parts and uploaded in sequence,
#                           followed by a summary message with reassembly notes.
# - Build failed          -> sends a failure message.
# Credentials come from environment or config/.env.local (never committed).
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHANNEL_ID" ]; then
    log "TELEGRAM_BOT_TOKEN / TELEGRAM_CHANNEL_ID not set - skipping Telegram."
    exit 0
fi

API="https://api.telegram.org/bot${BOT_TOKEN}"
MAX_SIZE=52428800 # 50 MB Telegram bot limit

# Optional text message mode
MESSAGE="${1:-}"

# Resolve module path
if [ -f "$WORK_DIR/.module" ]; then
    source "$WORK_DIR/.module"
fi

VERSION="$(read_json "['youtube_version']")"
PART_LIMIT=48 # MB per part (safety margin under the 50 MB limit)

send_message() {
    local text="$1"
    curl -fsSL --form-string "chat_id=$CHANNEL_ID" \
        --form-string "text=$text" \
        --form-string "parse_mode=HTML" "$API/sendMessage" >/dev/null \
        && log "Pesan terkirim ke channel $CHANNEL_ID" \
        || { echo "Telegram sendMessage gagal (cek token/channel)."; exit 1; }
}

send_file() {
    local file="$1" caption="$2"
    curl -fsSL -F "chat_id=$CHANNEL_ID" \
        -F "document=@$file" \
        --form-string "caption=$caption" \
        --form-string "parse_mode=HTML" "$API/sendDocument" >/dev/null \
        || { echo "Telegram sendDocument gagal untuk $file."; exit 1; }
}

if [ -n "$MESSAGE" ]; then
    send_message "$MESSAGE"
    exit 0
fi

[ -f "$MODULE_ZIP" ] || fail "Module zip tidak ditemukan: $MODULE_ZIP"
SIZE="$(stat -c %s "$MODULE_ZIP")"

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

FILESIZE=$(du -h "$MODULE_ZIP" | cut -f1)

if [ "$SIZE" -le "$MAX_SIZE" ]; then
    send_file "$MODULE_ZIP" "<b>📺 YouTube ReVanced Extended v${VERSION}</b>
✅ Build selesai - module siap di-flash via Magisk/KSU/Apatch.

<b>Patch:</b>
${SUMMARY}"

    send_message "📦 <b>${MODULE_NAME}</b> (${FILESIZE})
File dikirim di atas. Selamat menikmati! ✨"
else
    log "Module ${FILESIZE} > 50MB - split menjadi beberapa part."
    PARTS_DIR="$WORK_DIR/parts"
    rm -rf "$PARTS_DIR" && mkdir -p "$PARTS_DIR"
    split -b "${PART_LIMIT}M" "$MODULE_ZIP" "$PARTS_DIR/part-"

    PARTS=("$PARTS_DIR"/part-*)
    TOTAL=${#PARTS[@]}
    IDX=0
    for PART in "${PARTS[@]}"; do
        IDX=$((IDX + 1))
        PART_NAME="YouTube.RVX.v${VERSION}.zip.part-${IDX}-of-${TOTAL}"
        log "Mengirim part $IDX/$TOTAL..."
        curl -fsSL --form-string "chat_id=$CHANNEL_ID" \
            -F "document=@$PART;filename=$PART_NAME" \
            --form-string "caption=<b>📺 YouTube RVX v${VERSION}</b> — part <b>${IDX}/${TOTAL}</b>" \
            --form-string "parse_mode=HTML" "$API/sendDocument" >/dev/null \
            || { echo "Gagal mengirim part $IDX."; exit 1; }
    done

    send_message "<b>📺 YouTube ReVanced Extended v${VERSION}</b>
✅ Build selesai (${FILESIZE}) — file terpecah jadi <b>${TOTAL} part</b>.

<b>Patch:</b>
${SUMMARY}

<b>Cara gabung part:</b>
1. Download semua part (part-1 sampai part-${TOTAL}).
2. Gabungkan berurutan dengan aplikasi <i>Split & Merge</i> / <i>Zip Merge</i>, atau via PC: <code>cat part-* &gt; module.zip</code>.
3. Flash hasil gabungan via Magisk / KSU / Apatch."
fi
