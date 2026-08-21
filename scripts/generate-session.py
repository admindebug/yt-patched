#!/usr/bin/env python3
"""Generate STRING_SESSION Telethon untuk upload Telegram pakai akun user.

Akun user punya limit upload 2 GB (4 GB kalau Premium), jadi module zip
±300 MB bisa sekali kirim tanpa di-split.

Cara pakai:
    pip install telethon
    python3 scripts/generate-session.py

API_ID / API_HASH didapat dari https://my.telegram.org (API development tools).
"""
import os

try:
    from telethon.sync import TelegramClient
    from telethon.sessions import StringSession
except ImportError:
    raise SystemExit("Telethon belum terpasang. Jalankan: pip install telethon")


def ask(env, prompt):
    value = os.environ.get(env, "").strip()
    if value:
        print(f"{prompt}: (dari environment)")
        return value
    return input(f"{prompt}: ").strip()


def main():
    api_id = ask("TELEGRAM_API_ID", "API_ID")
    api_hash = ask("TELEGRAM_API_HASH", "API_HASH")
    phone = ask("TELEGRAM_PHONE", "Nomor HP (format internasional, contoh +62812xxxxxxx)")

    if not api_id or not api_hash or not phone:
        raise SystemExit("API_ID, API_HASH, dan nomor HP wajib diisi.")

    print("\nKode login akan dikirim ke Telegram kamu. Cek chatnya.\n")

    with TelegramClient(StringSession(), int(api_id), api_hash) as client:
        me = client.get_me()
        session = client.session.save()

    print("=" * 60)
    print("Login berhasil sebagai:", me.first_name, f"(@{me.username})" if me.username else "")
    print("=" * 60)
    print("\nSTRING_SESSION kamu:\n")
    print(session)
    print("\nSimpan ke config/.env.local (lokal) dan GitHub Secrets:")
    print('  TELEGRAM_API_ID="<api_id>"')
    print('  TELEGRAM_API_HASH="<api_hash>"')
    print('  TELEGRAM_STRING_SESSION="<session di atas>"')
    print("JANGAN bagikan string ini ke siapa pun - itu akses penuh akunmu!")


if __name__ == "__main__":
    main()
