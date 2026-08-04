#!/usr/bin/env python3
"""Download the stock base APK of a given package/version from APKMirror."""
import re
import sys
import urllib.error
import urllib.request

UA = ("Mozilla/5.0 (Linux; Android 14; Pixel 8) "
      "AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36")

APP_SLUG = "youtube"
APK_MIRROR = "https://www.apkmirror.com"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("utf-8", "replace")


def fetch_bytes(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()


def http_status(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status
    except urllib.error.HTTPError as err:
        return err.code
    except Exception:
        return 0


def find_release_page(version):
    slug = version.replace(".", "-")
    url = f"{APK_MIRROR}/apk/google-inc/{APP_SLUG}/{APP_SLUG}-{slug}-release/"
    if http_status(url) == 200:
        return url
    # Fallback: search the app page for a matching version link
    page = fetch(f"{APK_MIRROR}/apk/google-inc/{APP_SLUG}/")
    for _ in range(3):  # paginate a little
        m = re.search(r'href="([^"]*' + re.escape(slug) + r'[^"]*release/)"', page)
        if m:
            return APK_MIRROR + m.group(1)
        m = re.search(r'href="([^"]*/page/\d+/)"', page)
        if not m:
            break
        page = fetch(APK_MIRROR + m.group(1))
    return url  # let a later fetch fail with a clear error


def pick_variant(html):
    """Pick the best base APK variant: universal/nodpi > arm64 > first."""
    rows = re.findall(
        r'class="table-cell rowheight addseparator expand pad dowrap">([^<]*)</div>'
        r'.*?class="table-cell rowheight addseparator expand pad dowrap">([^<]*)</div>'
        r'.*?class="table-cell rowheight addseparator expand pad dowrap">([^<]*)</div>'
        r'.*?href="([^"]*)"',
        html, re.S)
    candidates = []
    for arch, minsdk, dpi, link in rows:
        candidates.append((arch.strip(), minsdk.strip(), dpi.strip(), link.strip()))
    if not candidates:
        raise SystemExit("No APK variant found on the release page.")

    def score(c):
        arch, _, dpi, _ = c
        s = 0
        if "universal" in arch:
            s += 100
        if "arm64" in arch:
            s += 50
        if "nodpi" in dpi:
            s += 20
        return s

    return max(candidates, key=score)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {sys.argv[0]} <version> <output.apk>")
    version, output = sys.argv[1], sys.argv[2]

    release_url = find_release_page(version)
    html = fetch(release_url)
    _, _, _, variant_link = pick_variant(html)

    download_page = fetch(APK_MIRROR + variant_link)
    m = re.search(r'href="([^"]*/download/\?key=[^"]*)"', download_page)
    if not m:
        raise SystemExit("No download link found on the variant page.")
    key_page = fetch(APK_MIRROR + m.group(1))

    m = re.search(r'id="download-link"[^>]*href="([^"]*)"', key_page)
    if not m:
        m = re.search(r'href="(/wp-content/themes/APKMirror/download\.php[^"]*)"', key_page)
    if not m:
        raise SystemExit("No CDN download link found.")
    cdn_url = APK_MIRROR + m.group(1)

    data = fetch_bytes(cdn_url)
    with open(output, "wb") as fh:
        fh.write(data)
    print(f"Downloaded {version} APK ({len(data)} bytes) -> {output}")


if __name__ == "__main__":
    main()
