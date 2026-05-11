# NativeDropBridge WM_COPYDATA Protocol

## Purpose
- The Go bridge sends drag events as JSON via `WM_COPYDATA (0x4A)` to a hidden AHK window.
- AHK parses and routes events in real time, without relying on file polling.

## Window Discovery
- `FindWindow(class, title)`:
1. `class`: `AutoHotkey`
2. `title`: `NMER_AHK_BRIDGE`

## COPYDATASTRUCT
1. `dwData`: `1` (protocol marker/version id)
2. `cbData`: UTF-8 JSON byte length, including trailing `\0`
3. `lpData`: pointer to UTF-8 JSON bytes

## JSON Fields
1. `at`: RFC3339 timestamp
2. `kind`: `bridge_ready|drag_start|drag_enter|drag_end|drop|DRAG_END_PHYSICAL`
3. `payloadKind`: `text|link|file|folder|mixed|none`
4. `sourceFormat`: `CF_HDROP|FileGroupDescriptorW|CF_UNICODETEXT`
5. `text` / `link`
6. `files` / `folders`
7. `count`: total item count
8. `x` / `y`: screen coordinates
9. `w` / `h`: optional init dimensions (for `bridge_ready`)

## Compatibility and Fallback
1. Primary path: `WM_COPYDATA` real-time routing.
2. If no copydata event arrives within `copydataFallbackMs`, AHK enables JSONL polling fallback.
3. Keep JSONL output for diagnostics and replay.
