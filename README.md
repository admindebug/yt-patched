# YouTube ReVanced Patch

YouTube patched tanpa iklan + fitur premium, dibangun pakai [Revancify Tools](https://github.com/decipher3114/Revancify).

Build-nya otomatis lewat GitHub Actions tiap hari, hasilnya dikirim ke channel Telegram. Detail alurnya ada di bawah.

## Cara Kerja Pipeline

Build dijalankan oleh GitHub Actions (jadwal harian atau manual), alurnya kira-kira begini:

```
fetch-sources.sh  → ambil Morphe CLI + patches Anddea (.mpp) terbaru
detect-version.sh → cari versi YouTube terbaru yang didukung patch
download-apk.sh   → download APK stock dari APKMirror
patch-apk.sh      → patch APK sesuai config/patches.json
build-module.sh   → rakit jadi zip module Magisk
update-json.sh    → update update.json + changelog.md
GitHub Release    → publish zip ke halaman release
telegram.sh       → kirim link + ringkasan ke channel
```

> [!NOTE]
> Ukuran module zip ±300 MB, sedangkan batas upload bot Telegram cuma 50 MB. Jadi yang dikirim ke Telegram adalah **link release** + ringkasan patch. Kalau ukuran module di bawah 50 MB (jarang terjadi), filenya dikirim langsung.

## Setup Pertama Kali

1. Push project ini ke repo GitHub kamu.
2. Tambah secrets di `Settings → Secrets and variables → Actions`:
   | Secret | Isi |
   |--------|-----|
   | `TELEGRAM_BOT_TOKEN` | Token bot dari @BotFather |
   | `TELEGRAM_CHANNEL_ID` | ID channel, format `-100xxxxxxxxxx` |
3. Jalankan workflow `Build & Release Module` dari tab **Actions**, atau tunggu jadwal hariannya.

> [!CAUTION]
> **Jangan pernah simpan BOT_TOKEN di file atau kode.** Token cuma boleh ada di GitHub Secrets. Kalau token sudah terlanjur bocor, langsung buat ulang via @BotFather.

## Atur Patch

Patch diatur lewat `config/patches.json`:

```json
{
  "youtube_version": "20.51.39",
  "patches": [
    { "name": "Hide ads" },
    { "name": "Settings for YouTube" },
    { "name": "Custom branding name for YouTube",
      "options": { "customName": "YouTube RVX" } }
  ]
}
```

- Daftar patch tinggal ditambah/dikurangi sesuai selera. Nama patch yang valid bisa dicek via `scripts/detect-version.sh`.
- `youtube_version` bisa diisi manual saat trigger workflow, atau dikosongkan biar auto-detect versi terbaru.

## Build di Lokal (Termux / PC)

```bash
# Siapkan kredensial Telegram dulu (JANGAN di-commit):
cp config/.env.local.example config/.env.local
# isi TELEGRAM_BOT_TOKEN dan TELEGRAM_CHANNEL_ID

# Build langsung + kirim ke Telegram (auto-split kalau > 50 MB):
./scripts/build-local.sh                # pakai versi di config/patches.json
./scripts/build-local.sh 20.51.39       # atau paksa versi tertentu
```

Kalau mau jalan pelan-pelan:

```bash
./scripts/fetch-sources.sh
./scripts/download-apk.sh
./scripts/patch-apk.sh                  # ini yang paling lama, ±30-50 menit
./scripts/build-module.sh               # hasil: out/YouTube.RVX.v<versi>.zip
./scripts/telegram.sh
```

> [!NOTE]
> - Butuh **Java 21 + ±3 GB RAM + ±40 menit**. Kalau build di HP: tutup aplikasi lain, colok charger, dan matikan battery optimization untuk Termux.
> - Module zip ±290 MB di-split jadi beberapa part saat dikirim via bot. File utuh juga ada di `/sdcard/Download/YouTube-RVX/`.

## Disclaimer

Saya buat ini untuk pemakaian pribadi. Pakai sendiri, tanggung risiko sendiri ya.

## About

Project ini menghasilkan **YouTube ReVanced** yang bebas iklan dan dapat fitur premium tanpa berlangganan. Mendukung **ROOT** dan **NON-ROOT**.

## Requirements

**Root:**
- KSU / Magisk / Apatch
- Jangan flash module lewat TWRP atau Custom Recovery lain!
- Versi minimum: Magisk `24200`, KSU `11425`

**Non-Root:**
- GmsCore (MicroG) untuk login akun Google
- YouTube ReVanced versi non-root

## Download GmsCore / MicroG

| Source | Download |
|--------|---------|
| [MicroG-RE (Morphe)](https://github.com/MorpheApp/MicroG-RE/releases/latest) | Recommended |
| [MicroG-RE (Better UI)](https://github.com/wstxda/microg-re/releases/latest) | Opsional |
| [GmsCore dari ReVanced](https://github.com/revanced/gmscore/releases/latest) | Alternatif |
| [GmsCore dari YT-Advanced](https://github.com/yt-advanced/gmscore/releases/latest) | Alternatif |

## Cara Install

**Root:**
1. Download module (versi Root)
2. Install lewat Magisk / KSU / Apatch
3. Export settings (opsional)
4. Selesai

**Non-Root:**
1. Install GmsCore (MicroG)
2. Download & install YouTube ReVanced versi non-root
3. Export settings (opsional)
4. Selesai

## Kredit

- [Revancify](https://github.com/decipher3114/Revancify) — decipher3114
- [Revancify Xisr](https://github.com/Xisrr1/Revancify-Xisr) — Xisrr1
- [YouTube ReVanced](https://github.com/revanced) — team ReVanced
- [Anddea Patch](https://github.com/anddea/revanced-patches) — anddea
- [Morphe CLI](https://github.com/MorpheApp/morphe-cli) — MorpheApp
