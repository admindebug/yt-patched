#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require java

# Detect the newest YouTube version supported by the Anddea .mpp patches.
# Outputs the version to stdout and caches it in WORK_DIR/.ytversion.
CLI_FILE="$(cat "$WORK_DIR/.cli")"
PATCHES_FILE="$(cat "$WORK_DIR/.patches")"

log "Detecting latest supported YouTube version..."
java -jar "$CLI_FILE" list-patches -p -v --patches="$PATCHES_FILE" > "$WORK_DIR/patch-list.txt" 2>/dev/null

LIST_FILE="$WORK_DIR/patch-list.txt" python3 - <<'EOF'
import os, re
txt = open(os.environ["LIST_FILE"]).read()
blocks = re.split(r"\n(?=Name: )", txt)
versions = set()
for b in blocks:
    m = re.search(r"Package name: com\.google\.android\.youtube\s*\n\s*Compatible versions:\s*\n((?:\s+\d[\d.]*\s*\n)+)", b)
    if m:
        for v in re.findall(r"(\d+(?:\.\d+)+)", m.group(1)):
            versions.add(tuple(int(x) for x in v.split(".")))
if not versions:
    raise SystemExit("Could not determine supported YouTube version.")
best = max(versions)
print(".".join(map(str, best)))
EOF
