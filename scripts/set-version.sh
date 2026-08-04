#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require python3

# Overrides youtube_version in config/patches.json (used by CI for manual/auto versions)
VERSION="${1:?Usage: set-version.sh <version>}"
CONFIG_FILE="$CONFIG_FILE" VERSION="$VERSION" python3 - <<'EOF'
import json, os
path = os.environ["CONFIG_FILE"]
with open(path) as fh:
    cfg = json.load(fh)
cfg["youtube_version"] = os.environ["VERSION"]
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
print(f"Set youtube_version -> {os.environ['VERSION']}")
EOF
