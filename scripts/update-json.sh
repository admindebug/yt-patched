#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Regenerates changelog.md and update.json at the repo root so that
# Magisk can fetch updates via the raw GitHub URLs in update.json.
VERSION="$(read_json "['youtube_version']")"
REPO="${GITHUB_REPOSITORY:-admindebug/yt-patched}"
TAG="v$VERSION"
DATE="$(date +%Y-%m-%d)"

CHANGELOG="$PROJECT_DIR/changelog.md"
TMPLOG="$WORK_DIR/changelog-new.md"

# Prepend a new entry; keep it short.
cat > "$TMPLOG" <<EOF
## $TAG ($DATE)

### Update
- Auto-built with GitHub Actions (Morphe CLI + Anddea patches)
- YouTube $VERSION - all configured patches applied

### Fix & Problem
- If buffering occurs: Settings > ReVanced > Misc > Spoof client - switch client
- For Non-Root, if "Package incompatible" appears, uninstall the old version first

\`Note: Always Read README.MD first!\`
EOF
[ -f "$CHANGELOG" ] && tail -n +2 "$CHANGELOG" >> "$TMPLOG"
cp "$TMPLOG" "$CHANGELOG"

# update.json at repo root (raw URL, used by Magisk update channel)
python3 - "$REPO" "$VERSION" "$(date +%Y%m%d%H%M)" <<'EOF' > "$PROJECT_DIR/update.json"
import json, sys
repo, version, code = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "version": f"v{version}",
    "versionCode": int(code),
    "zipUrl": f"https://github.com/{repo}/releases/download/v{version}/YouTube.RVX.v{version}.zip",
    "changelog": f"https://raw.githubusercontent.com/{repo}/main/changelog.md",
    "releaseType": "stable"
}, indent=2))
EOF

log "Updated $CHANGELOG and $PROJECT_DIR/update.json"
