# Global Drag -> Wails Hole (AHK Frontend Plan)

## What this delivers

- Desktop-global pre-judge (AHK, no browser required for trigger path).
- Auto show/hide overlay window.
- Drive hole frontend via:
  - `window.HoleOverlay.show(payload)`
  - `window.HoleOverlay.update({payload,x,y})`
  - `window.HoleOverlay.drop({payload})`
  - `window.HoleOverlay.hide()`

## Start

Run:

`tools/dev/run_global_drag_hole_overlay.ahk`

Stop:

`Ctrl+Alt+H`

## Current pre-judge strategy

1. Detect left-button hold + movement threshold.
2. If source window class is Explorer/Desktop (`CabinetWClass/ExploreWClass/WorkerW/Progman`), treat as file/folder drag.
3. Otherwise, if cursor shape changed after movement, treat as drag candidate.
4. While candidate active, keep sending pointer updates to hole frontend.
5. On release, send `drop`, then hide overlay.

## Configure page URL

In `run_global_drag_hole_overlay.ahk`:

`GDHO_SetPageUrl("http://127.0.0.1:5173/hole.html")`

If you later package Wails and expose a local page URL, replace this with that URL.

## Notes

- This is an AHK **pre-judge** implementation. It is intentionally fast and practical.
- For strict payload detection (especially cross-app text drag fidelity), next step is adding a native/OLE drag monitor in Go.
