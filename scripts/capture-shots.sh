#!/usr/bin/env bash
# Captures the product screenshots for the README and the website from real app windows.
# Run it from a Terminal that has Screen Recording permission:  scripts/capture-shots.sh
# It launches an isolated agent-mode copy (its own settings store, never your real settings) per shot, captures only that
# app's own windows (never the whole screen), and writes raw files to docs/images/raw/.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/dev/Build/Products/Debug/Cursorlight.app/Contents/MacOS/Cursorlight"
OUT="docs/images/raw"
CW="$(mktemp -d)/capture-windows"
swiftc -O scripts/capture-windows.swift -o "$CW" 2>/dev/null
mkdir -p "$OUT"

ONLY="${1:-}"   # optional: only shots whose name-appearance contains this text, for example "look-light"

shoot() { # name open-target appearance [guide step]
  local name="$1" target="$2" appearance="$3" step="${4:-}" dir
  if [ -n "$ONLY" ] && [[ "$name-$appearance" != *"$ONLY"* ]]; then return; fi
  dir="$(mktemp -d)"
  CURSORLIGHT_AGENT=1 CURSORLIGHT_DEMO=1 CURSORLIGHT_DEFAULTS=cursorlight.shots CURSORLIGHT_APPEARANCE="$appearance" \
    CURSORLIGHT_GUIDE_STEP="$step" CURSORLIGHT_OPEN="$target" "$APP" >/dev/null 2>&1 &
  local pid=$!
  sleep 4
  if [ -n "$step" ]; then "$CW" "$dir" --all >/dev/null 2>&1 || true; else "$CW" "$dir" >/dev/null 2>&1 || true; fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [ -n "$step" ]; then # the guide card and its hint are separate windows: keep both
    local i=0; for f in "$dir"/window-*.png; do [ -e "$f" ] || continue; i=$((i+1)); cp "$f" "$OUT/$name-$appearance-$i.png"; done; echo "ok  $name-$appearance ($i windows)"; return
  fi
  # The largest capture is the content window.
  local best; best="$(ls -S "$dir"/window-*.png 2>/dev/null | head -1 || true)"
  if [ -n "$best" ]; then cp "$best" "$OUT/$name-$appearance.png"; echo "ok  $name-$appearance"; else echo "MISSING $name-$appearance"; fi
}

for appearance in dark light; do
  shoot look settings:highlight "$appearance"
  shoot draw settings:ink "$appearance"
  shoot keys settings:triggers "$appearance"
  shoot apps settings:profiles "$appearance"
  shoot screens settings:displays "$appearance"
  shoot about settings:about "$appearance"
  shoot popover popover "$appearance"
  for step in intro shake laser ink done; do shoot "guide-$step" welcome "$appearance" "$step"; done
done
defaults delete cursorlight.shots 2>/dev/null || true
echo done
