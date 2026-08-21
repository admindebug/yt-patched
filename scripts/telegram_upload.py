#!/usr/bin/env python3
"""Upload hasil build ke Telegram.

Mode utama  : akun user via Telethon (TELEGRAM_STRING_SESSION).
              Limit upload 2 GB per file, jadi module zip dikirim utuh tanpa split.
              Upload pakai FastTelethon (banyak koneksi paralel) agar cepat,
              dengan fallback ke upload standar kalau gagal.
              Format kirim:
                1. Pesan changelog (dalam blockquote)
                2. MicroG.apk
                3. YTPatched_NON_ROOT-<versi>.apk
                4. YTPatched_ROOT-<versi>.zip
Mode fallback: Bot API (TELEGRAM_BOT_TOKEN), batas 50 MB per file.
              File >50 MB tidak dikirim (tidak ada split lagi).

Pesan teks saja: ./scripts/telegram.sh "pesan"
Dry run        : DRY_RUN=1 ./scripts/telegram.sh
"""
import asyncio
import html
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.environ.get("CONFIG_FILE") or os.path.join(PROJECT_DIR, "config", "patches.json")
WORK_DIR = os.environ.get("WORK_DIR") or os.path.join(PROJECT_DIR, "work")
OUT_DIR = os.environ.get("OUT_DIR") or os.path.join(PROJECT_DIR, "out")

SESSION = os.environ.get("TELEGRAM_STRING_SESSION") or os.environ.get("STRING_SESSION") or ""
API_ID = os.environ.get("TELEGRAM_API_ID") or os.environ.get("API_ID") or ""
API_HASH = os.environ.get("TELEGRAM_API_HASH") or os.environ.get("API_HASH") or ""
BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN") or ""
CHANNEL = (os.environ.get("TELEGRAM_CHANNEL_ID") or "").strip()
DRY_RUN = os.environ.get("DRY_RUN", "") == "1"

BOT_MAX = 50 * 1024 * 1024  # 50 MB limit Bot API


def log(msg):
    print(f"[telegram] {msg}", file=sys.stderr)


def die(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def load_version():
    try:
        with open(CONFIG_FILE) as fh:
            return json.load(fh)["youtube_version"]
    except (OSError, KeyError, json.JSONDecodeError) as err:
        die(f"Cannot read youtube_version from {CONFIG_FILE}: {err}")


def changelog_first_entry():
    """Ambil entry paling atas dari changelog.md sebagai teks blockquote."""
    path = os.path.join(PROJECT_DIR, "changelog.md")
    try:
        with open(path) as fh:
            txt = fh.read()
    except OSError:
        return ""
    entry = re.split(r"\n(?=## )", txt)[0].strip()
    return entry


def md_to_telegram_html(md_text):
    """Konversi markdown changelog sederhana ke HTML yang bisa dirender Telegram."""
    text = html.escape(md_text)
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("### "):
            lines.append(f"<b><u>{stripped[4:]}</u></b>")
        elif stripped.startswith("## "):
            lines.append(f"<b>{stripped[3:]}</b>")
        elif stripped.startswith("# "):
            lines.append(f"<b>{stripped[2:]}</b>")
        elif stripped.startswith("- "):
            lines.append(f"\u2022 {stripped[2:]}")
        else:
            lines.append(line)
    text = "\n".join(lines)
    # Inline code `x` -> <code>x</code>, link [t](u) -> <a href="u">t</a>
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def build_caption(version):
    lines = [f"<b>YouTube Patched FALABS v{version}</b>"]
    entry = changelog_first_entry()
    if entry:
        lines += ["", f"<blockquote>{md_to_telegram_html(entry)}</blockquote>"]
    lines += [
        "",
        "<b>Download:</b>",
        f"1. MicroG.apk - wajib untuk Non-Root",
        f"2. YTPatched_NON_ROOT-{version}.apk - install langsung (Non-Root)",
        f"3. YTPatched_ROOT-{version}.zip - module Root (Magisk/KSU/Apatch)",
    ]
    return "\n".join(lines)


def read_module_zip():
    path = os.path.join(WORK_DIR, ".module")
    if os.path.isfile(path):
        with open(path) as fh:
            for line in fh:
                if line.startswith("MODULE_ZIP="):
                    return line.split("=", 1)[1].strip()
    return None


def resolve_files(version):
    """Kembalikan daftar (path_asli, nama_file_di_telegram). Urutan sesuai spek."""
    files = []

    microg = next((p for p in (
        os.path.join(OUT_DIR, "MicroG.apk"),
        os.path.join(WORK_DIR, "microg.apk"),
        os.path.join(WORK_DIR, "MicroG.apk"),
    ) if os.path.isfile(p)), None)
    if microg:
        files.append((microg, "MicroG.apk"))
    else:
        log("MicroG.apk tidak ditemukan - lewati (jalankan scripts/fetch-microg.sh).")

    patched = os.path.join(WORK_DIR, "youtube-patched.apk")
    if os.path.isfile(patched):
        files.append((patched, f"YTPatched_NON_ROOT-{version}.apk"))
    else:
        log(f"APK patched tidak ditemukan ({patched}) - lewati.")

    root_zip = None
    for cand in (read_module_zip(), os.path.join(OUT_DIR, f"YouTube.RVX.v{version}.zip"),
                 os.path.join(OUT_DIR, f"YTPatched_ROOT-{version}.zip")):
        if cand and os.path.isfile(cand):
            root_zip = cand
            break
    if root_zip:
        files.append((root_zip, f"YTPatched_ROOT-{version}.zip"))
    else:
        die("Module zip tidak ditemukan. Build dulu via build-module.sh.")

    return files


def entity_id():
    if not CHANNEL:
        die("TELEGRAM_CHANNEL_ID tidak diset.")
    return int(CHANNEL) if re.fullmatch(r"-?\d+", CHANNEL) else CHANNEL


async def _fast_upload(client, path):
    """Upload file ke server Telegram pakai banyak koneksi paralel (FastTelethon)."""
    from fast_telethon import upload_file
    with open(path, "rb") as fh:
        return await upload_file(client, fh)


async def _send_telethon(message, files, version):
    from telethon import TelegramClient
    from telethon.sessions import StringSession
    from telethon.tl.types import DocumentAttributeFilename, InputMediaUploadedDocument

    MIME = {
        ".apk": "application/vnd.android.package-archive",
        ".zip": "application/zip",
    }

    async with TelegramClient(StringSession(SESSION), int(API_ID), API_HASH) as client:
        entity = entity_id()
        await client.send_message(entity, message, parse_mode="html", link_preview=False)
        log("Pesan changelog terkirim.")

        if not files:
            return

        # Upload handle semua file secara paralel (masing-masing multi-koneksi).
        import time
        t0 = time.monotonic()

        try:
            async def upload_one(src, name):
                log(f"Mengupload {name} ({os.path.getsize(src) // (1024 * 1024)} MB)...")
                handle = await _fast_upload(client, src)
                log(f"Upload {name} selesai.")
                ext = os.path.splitext(name)[1]
                return InputMediaUploadedDocument(
                    file=handle,
                    mime_type=MIME.get(ext, "application/octet-stream"),
                    attributes=[DocumentAttributeFilename(file_name=name)],
                    force_file=True,
                )

            media = list(await asyncio.gather(
                *[upload_one(src, name) for src, name in files]))
            captions = [None] * len(media)
            captions[-1] = f"YouTube Patched FALABS v{version}"
            await client.send_file(entity, media, caption=captions, parse_mode="html")
            log(f"{len(media)} file terkirim dalam {time.monotonic() - t0:.0f} detik "
                "(sekali kirim, tanpa split).")
        except Exception as err:
            log(f"Fast upload gagal ({err!r}) - fallback ke upload standar.")
            await _send_telethon_plain(client, entity, files, version)


async def _send_telethon_plain(client, entity, files, version):
    """Fallback: upload standar Telethon satu per satu."""
    for i, (src, name) in enumerate(files):
        await client.send_file(entity, src, file_name=name,
                               caption=name if i == len(files) - 1
                               else f"YouTube Patched FALABS v{version}",
                               force_document=True)
        log(f"{name} terkirim (mode lambat).")


def send_telethon(message, files, version):
    asyncio.run(_send_telethon(message, files, version))


def bot_api(method, **data):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/{method}"
    payload = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=payload)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode())
            if not body.get("ok"):
                raise RuntimeError(body.get("description", "unknown error"))
    except Exception as err:
        die(f"Bot API {method} gagal: {err}")


def bot_send_file(path, name, caption):
    size = os.path.getsize(path)
    if size > BOT_MAX:
        die(f"{name} ({size // (1024 * 1024)} MB) melebihi batas 50 MB Bot API. "
            "Set TELEGRAM_STRING_SESSION untuk upload sekali kirim.")
    result = subprocess.run(
        ["curl", "-fsSL",
         "-F", f"chat_id={CHANNEL}",
         "-F", f"document=@{path};filename={name}",
         "--form-string", f"caption={caption}",
         "--form-string", "parse_mode=HTML",
         f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"],
        capture_output=True, text=True)
    if result.returncode != 0:
        die(f"Gagal upload {name} via Bot API: {result.stderr.strip()}")
    log(f"{name} terkirim via Bot API.")


async def _send_text(text):
    from telethon import TelegramClient
    from telethon.sessions import StringSession

    async with TelegramClient(StringSession(SESSION), int(API_ID), API_HASH) as client:
        await client.send_message(entity_id(), text, parse_mode="html", link_preview=False)


def main():
    message_only = sys.argv[1] if len(sys.argv) > 1 else ""

    if not SESSION and not BOT_TOKEN:
        log("TELEGRAM_STRING_SESSION / TELEGRAM_BOT_TOKEN tidak diset - skipping Telegram.")
        return
    if SESSION and (not API_ID or not API_HASH):
        die("TELEGRAM_STRING_SESSION diset tapi TELEGRAM_API_ID / TELEGRAM_API_HASH kosong.")

    version = load_version()

    if message_only:
        if SESSION:
            asyncio.run(_send_text(message_only))
            log("Pesan terkirim.")
        else:
            bot_api("sendMessage", chat_id=CHANNEL, text=message_only,
                    parse_mode="HTML", disable_web_page_preview="true")
        return

    caption = build_caption(version)
    files = resolve_files(version)

    if DRY_RUN:
        print("--- caption ---")
        print(caption)
        print("--- files ---")
        for src, name in files:
            print(f"{name}  <-  {src} ({os.path.getsize(src) // (1024 * 1024)} MB)")
        return

    if SESSION:
        send_telethon(caption, files, version)
    else:
        log("Mode Bot API (tanpa STRING_SESSION) - file >50 MB tidak akan terkirim.")
        bot_api("sendMessage", chat_id=CHANNEL, text=caption,
                parse_mode="HTML", disable_web_page_preview="true")
        for i, (src, name) in enumerate(files, 1):
            bot_send_file(src, name, f"YouTube Patched FALABS v{version} ({i}/{len(files)})")


if __name__ == "__main__":
    main()
