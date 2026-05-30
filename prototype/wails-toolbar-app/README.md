# NMER Wails Toolbar App (Skeleton)

> **已废弃**：双击 CapsLock 现由 `modules/CommandPaletteCore.ahk` + `CommandPalette.html`（AHK WebView2）提供 Raycast 命令面板。本目录仅保留参考，无需再 `wails build` 或部署 `nmer-wails-input.exe`。

## 1) Install frontend deps
```powershell
cd frontend
npm install
cd ..
```

## 2) Run in dev mode
```powershell
wails dev
```

## 3) Build exe
```powershell
wails build
```

Window title is `NMER Wails Input`.
Use this title/exe in your AHK activation rule.
