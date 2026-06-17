; ChordPad 宿主符号声明（仅 LSP / IntelliSense，不参与运行）
; 与 modules\ChordPad.ahk 同名，vscode-autohotkey2-lsp 会自动 @reference

FuncExists(fnName) {
}

WebView2_CreateWithSharedEnvAsync(hwnd, callback, tag := "") {
}

ApplyWebView2PerformanceSettings(wv2) {
}

WebView2_RegisterHostBridge(wv2) {
}

ApplyUnifiedWebViewAssets(wv2) {
}

BuildAppLocalUrl(relPath) {
}

NmerCatch(funcName, err) {
}

ChordUsage_GetScore(cmdId) {
}

ChordUsage_SortSlots(slots) {
}

VK_Execute(cmdId) {
}

HandleDynamicHotkey(PressedKey, ActionType) {
}

CursorPanel_RunQuickAction(btnType) {
}

VK_NoteLastExecutedId(cmdId) {
}

VK_NoteLastChFromCapsLockKey(keyLower) {
}

RestoreCapsLockAfterChord(*) {
}

Nmer_DataStatePath(fileName) {
}

ShowPanelTimer(*) {
}

ChordPad_IconLucideFor(action := "", cmdId := "") {
}

global g_Commands := Map()

global g_InverseBindings := Map()

_VK_IsBareSingleKey(k) {
}

_LoadCommands() {
}

LoadCommandsConfig() {
}

IsSearchCenterActive() {
}

VK_IsClipboardPanelActive() {
}

IsScreenshotEditorActive() {
}

VK_SearchCenterResolveCapsChordCmd(physKey) {
}

VK_LookupBindingCmdForPhys(physKey) {
}

ChordPad_SetScale(scale, height := 0) {
}

ChordPad_ResizeToContent(w, h, anchorBottom := true) {
}
