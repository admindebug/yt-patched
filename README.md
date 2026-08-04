<h1 align="center">📺 YouTube ReVanced Patch</h1>

<p align="center">
  <b>A patched version of YouTube with ad-free experience and premium features using <a href="https://github.com/decipher3114/Revancify">Revancify Tools</a></b>  
</p>

> ⚡ **Auto-build pipeline** — setiap build di-generate otomatis oleh GitHub Actions dan dikirim ke channel Telegram. Lihat [Cara Pakai Pipeline](#-auto-build-pipeline) di bawah.

‎

## 🛠️ Auto-Build Pipeline

Project ini memiliki pipeline **CI/CD otomatis** yang melakukan patch, build module Magisk, rilis ke GitHub, lalu mengirim hasilnya ke channel Telegram.

### Alur Pipeline

```
GitHub Actions (schedule harian / manual)
  │
  ├─ fetch-sources.sh   → download Morphe CLI + patches Anddea (.mpp) terbaru
  ├─ detect-version.sh  → cari versi YouTube terbaru yang didukung patch
  ├─ download-apk.sh    → download APK stock dari APKMirror (scraper)
  ├─ patch-apk.sh       → patch APK (Morphe CLI, pilih patch dari config)
  ├─ build-module.sh    → rakit zip module Magisk (module.prop, customize.sh, dll)
  ├─ update-json.sh     → update update.json + changelog.md
  ├─ GitHub Release     → publish zip ke releases/<repo>
  └─ telegram.sh        → kirim link release + ringkasan ke channel Telegram
```

> [!NOTE]
> File module zip (±300 MB) **melebihi batas upload bot Telegram (50 MB)**, jadi Telegram menerima **link release + ringkasan patch** — file di-download dari GitHub Releases. (Jika module < 50 MB, file dikirim langsung.)

### Setup Sekali (di GitHub)

1. **Buat repository GitHub** dari project ini lalu push.
2. **Tambahkan Secrets** di `Settings → Secrets and variables → Actions`:
   | Secret | Isi |
   |--------|-----|
   | `TELEGRAM_BOT_TOKEN` | Token bot Telegram (dari @BotFather) |
   | `TELEGRAM_CHANNEL_ID` | ID channel tujuan (format `-100xxxxxxxxxx`) |
3. Jalankan workflow `Build & Release Module` dari tab **Actions** (atau tunggu schedule harian).

> [!CAUTION]
> **JANGAN pernah menaruh BOT_TOKEN di file/kode.** Token hanya boleh ada di GitHub Secrets. Jika token pernah bocor, segera buat ulang via @BotFather (revoke) — bot tidak menyimpan token, hanya membaca dari env saat build berjalan.

### Kustomisasi Patch

Semua patch dikonfigurasi di **`config/patches.json`**:

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

- Ubah daftar `patches` sesuai keinginan (daftar nama valid bisa dicek via `scripts/detect-version.sh` / `list-patches`).
- `youtube_version` dapat di-override manual saat memicu workflow, atau dibiarkan kosong untuk auto-detect versi terbaru yang didukung.

### Menjalankan Build di Lokal (opsional)

```bash
./scripts/fetch-sources.sh
./scripts/download-apk.sh
./scripts/patch-apk.sh
./scripts/build-module.sh
# hasil: out/YouTube.RVX.v<versi>.zip
```



‎

## ⚠️ Disclaimer  
> **I only patch for personal use. Please use at your own risk!**  
‎
## 📌 About  
This project provides a **YouTube ReVanced** patch that enables an ad-free experience and premium features **without a subscription**.  
Supports both **ROOT** and **NON-ROOT** versions! 🚀  
‎
## 🔧 Requirements  

<h4>🎭 Root Users 🎭</h4>

✅ **Required:**  
> - **KSU / Magisk / Apatch**  
> - ❌ Do not flash module on **TWRP** or other Custom Recovery!  

🛠️ **Minimum Supported Versions:**  
> - **Magisk**: `24200`  
> - **KSU**: `11425`
---
<h4>🌈 Non-Root Users 🌈</h4>

✅ **Required:**  
> - **GmsCore (MicroG)** → Required for logging into a Google Account  
> - **YouTube ReVanced (Non-Root Version)**  

‎

## 📥 Download GmsCore/MicroG  

| Source | Download Link |
|--------|--------------|
| **MicroG-RE (Morphe)** | 🔗 [Download](https://github.com/MorpheApp/MicroG-RE/releases/latest) |
| **MicroG-RE (Better UI)** | 🔗 [Download](http://github.com/wstxda/microg-re/releases/latest) |
| **GmsCore from ReVanced** | 🔗 [Download](http://github.com/revanced/gmscore/releases/latest) |
| **GmsCore from YT-Advanced** | 🔗 [Download](http://github.com/yt-advanced/gmscore/releases/latest) |

> [!NOTE]
> Recommended to use MicroG-RE (Morphe)!

‎

## 🚀 Installation Guide  

<h3>🎭 Root</h3>  

1. **Download** the module (**Root Version**)  
2. **Install** via **Magisk** / **KSU** / **Apatch**  
3. **Export settings** (Optional)  
4. Enjoy ✨  

---

<h3>🌈 Non-Root</h3>  

1. **Install GmsCore (MicroG)**  
2. **Download & Install YouTube ReVanced (Non-Root Version)**  
3. **Export settings** (Optional)  
4. Enjoy ✨

‎

## 📜 Sources & References  
- 🔧 [Revancify Tools](https://github.com/decipher3114/Revancify)
- 🔧 [Revancify Xisr Tools](https://github.com/Xisrr1/Revancify-Xisr)
- 📺 [YouTube ReVanced Patches](https://github.com/revanced)  
- 🛠️ [Anddea Patch](https://github.com/anddea/revanced-patches)
