# Niuma (nmer) — Cursor Productivity Toolkit for Windows

[简体中文](README.md) | English

A Windows desktop efficiency tool built on **AutoHotkey v2** and **WebView2**, centered on **CapsLock** as a unified launcher for Cursor workflows: code actions, global search, clipboard history, screenshots, prompts, voice input, and floating UI.

## Quick Start

1. Download the latest **`牛马-nmer-*-portable.zip`** from [Releases](https://github.com/psterman/nmer/releases)
2. Install [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe)
3. Extract the zip to a fixed folder (e.g. `D:\Tools\nmer\`)
4. Run **`牛马.ahk`** (main entry script)

The portable package includes Everything, ttyd, SearchCenterCore, WebView2Loader, and other runtime binaries.

## Requirements

- Windows 10/11
- AutoHotkey v2.0+
- WebView2 Runtime (usually preinstalled)
- Cursor editor (for AI code workflows)

## Directory Layout

| Path | Purpose |
|------|---------|
| `牛马.ahk` | Main entry — double-click to start |
| `modules/` | Feature modules (AHK + injected JS) |
| `assets/`, `*.html` | WebView2 UI |
| `lib/` | Third-party AHK libraries and DLLs |
| `searchcore/` | Go search core + `SearchCenterCore.exe` |
| `tools/` | Bridges, diagnostics, rg/openlist |
| `config/user_studio.defaults.json` | LLM/settings template → local `user_studio.json` on first use |
| `Data/` | Runtime user data (screenshots, chat attachments) |
| `Cache/` | Logs and cache — safe to clear periodically |
| `docs/` | Technical documentation |
| `archive/` | Deprecated prototypes — not used by the current app |

See [软件介绍.md](软件介绍.md) (Chinese) for full architecture details.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
