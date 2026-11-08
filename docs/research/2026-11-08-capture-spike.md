# Capture spike results (2026-11-08)

Throwaway code: `spike/capture-spike.swift`. Not product code, not to be kept.
Method: ScreenCaptureKit screenshots of a blue test window with a red ring overlay on top, counting red pixels. macOS 26.7, one display.

| Case | Red ring pixels | Meaning |
|---|---|---|
| A. Full-display capture | 35860 | Overlay is captured |
| B. Single-window capture, overlay is a separate window | 0 | Overlay is NOT captured |
| C. Single-window capture, overlay attached as a child window of the shared window | 35654 | Overlay is captured |

## What this means
- Full-screen share: effects shown by Beacon reach viewers. Confirmed.
- Window share: a separate overlay is invisible to viewers. Confirmed, and it matches the user's original problem.
- Case C works only because the spike owned the shared window. Beacon cannot attach a child window to another app's window across processes, so C is not a usable fix on its own.

## Not verified
- Real Zoom, Meet and Teams behavior. Meet in a browser uses the browser's own capture, which is also window-only in window mode.
- Multi-display, Stage Manager, retina vs non-retina scaling.
- Whether the conferencing app draws the real cursor in window share (separate from our overlay).

## Decision
Option 1 for v1: full-screen share plus a Share-safe warning. Options 2 and 3 are later.

## Options for window share
1. Make full-screen share the supported path, and add the Share-safe check that warns when the user shares a single window.
2. Offer a "Share Beacon's mirror" mode: Beacon opens its own window showing a live copy of the target window with the effects drawn in, and the user shares that. Perch already does a live window copy, so the technique exists in this codebase family. Heavier, needs Screen Recording permission.
3. Viewer-side pointer (later): the viewer's app draws it, independent of capture.
