#!/usr/bin/env bash
# Packs build/Beacon.app into build/Beacon.dmg: a dark installer window with the Beacon art, the app on the left and
# an Applications shortcut on the right. The layout comes from scripts/dmg/settings.py (dmgbuild, no Finder scripting,
# so it also runs on CI). The artwork is scripts/dmg/background.tiff; after editing scripts/dmg/background.html
# regenerate it with scripts/dmg/render-background.mjs.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d build/Beacon.app ] || { echo "run scripts/build-app.sh first" >&2; exit 1; }

VENV=build/dmg-venv
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet "dmgbuild==1.6.7"
fi

# A leftover "Beacon" volume makes the new image mount as "Beacon 1", and the background alias then points at the wrong path.
if [ -d /Volumes/Beacon ]; then
  hdiutil detach /Volumes/Beacon -quiet || { echo "eject /Volumes/Beacon first" >&2; exit 1; }
fi

rm -f build/Beacon.dmg
BEACON_ROOT="$PWD" "$VENV/bin/dmgbuild" -s scripts/dmg/settings.py "Beacon" build/Beacon.dmg >/dev/null
echo "built build/Beacon.dmg"
