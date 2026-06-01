#Requires AutoHotkey v2.0
#SingleInstance Force
#Persistent

; Run from repo root recommended.
SetWorkingDir(A_ScriptDir "\..")

#Include ..\lib\WebView2.ahk
#Include ..\modules\WebView2SharedEnv.ahk
#Include ..\modules\AhkWebViewBridge.ahk
#Include ..\modules\GlobalDragHoleOverlay.ahk

; If your hole page is hosted by local dev server:
GDHO_SetPageUrl("http://127.0.0.1:5173/hole_starry.html")
if (IsSet(GDHO_DECOUPLED_TOPOLOGY) && GDHO_DECOUPLED_TOPOLOGY) {
    GDHO_SetPanelPageUrl("http://127.0.0.1:5173/hole_panel.html")
    panelPath := A_ScriptDir . "\..\html\hole_panel.html"
    panelFb := "file:///" . StrReplace(panelPath, "\", "/")
    try GDHO_SetPanelFallbackUrl(panelFb)
    try GDHO_SetPanelPageUrl(panelFb)
}

GDHO_Start()
TrayTip("Global Drag Hole", "Started. Drag text/file/folder on desktop to trigger hole. Ctrl+Alt+H to exit.", "Iconi Mute")

; Keep pointer seed clean on click lifecycle.
~*LButton:: {
    ; no-op; seed handled by poll timer
}

~*LButton Up:: {
    GDHO_ResetPointerSeed()
}

^!h:: {
    GDHO_Stop()
    ExitApp
}



