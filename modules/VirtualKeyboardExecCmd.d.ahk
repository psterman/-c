; VirtualKeyboardExecCmd 宿主符号声明（仅 LSP / IntelliSense，不参与运行）
; 与 modules\VirtualKeyboardExecCmd.ahk 同名，vscode-autohotkey2-lsp 会自动 @reference
; 实现分布在 牛马.ahk、VirtualKeyboardCore、SearchCenterWebViewCore、CapsLockDynamicHotkey 等

; --- 宿主全局（运行时在主脚本赋值）---
global CapsLock := false
global CapsLock2 := false
global BatchHotkey := ""
global IsCountdownActive := false
global g_LastExecutedCmdId := ""
global HotkeyESC := "", HotkeyC := "c", HotkeyV := "v", HotkeyX := "x", HotkeyE := "e"
global HotkeyR := "r", HotkeyO := "o", HotkeyQ := "q", HotkeyZ := "z", HotkeyT := "t", HotkeyF := "f", HotkeyP := "p"
global AppearanceActivationMode := "toolbar"
global ConfigFile := ""
global SearchCenterFilterType := ""
global SearchCenterWebKeyword := ""
global SearchCenterCurrentLimit := 50
global FloatingToolbarGUI := 0

; --- 主脚本 / Core ---
NotifyScript(targetTitle, payload) {
}
_ExecuteCommand(cmdId) {
}
VK_Show() {
}
ExecuteQuickActionByType(Type) {
}
CapsLockPaste() {
}
Nmer_PersistAndApplyActivationMode(mode) {
}

; --- CapsLock / 搜索中心 ---
HandleDynamicHotkey(PressedKey, ActionType) {
}
ShowSearchCenter() {
}
ShowSearchCenterFromMenu() {
}
IsSearchCenterActive() {
}
HandleSearchCenterF() {
}
ExecuteCountdownAction() {
}
SearchCenter_ShouldUseWebView() {
}

; --- SearchCenter WebView ---
SCWV_SetUnifiedMode(mode := "search", syncWeb := true) {
}
SCWV_OpenUnified(mode := "search", keyword := "", triggerSource := "") {
}
_SCWV_RunClipboardTimelineSearch(keyword := "", offset := 0, limit := 0) {
}
SCWV_PostJson(payload) {
}
SCWV_IsClipboardUnifiedActive() {
}

; --- 提示词快垫 ---
PromptQuickPad_HandleCapsLockB() {
}
PromptQuickPad_OpenCaptureDraft(initialText := "", forceExpand := true) {
}
PromptQuickPad_GetHostHwnd() {
}
PromptQuickPad_ShouldUseWebView() {
}
PromptQuickPad_QuickCapture() {
}
PromptQuickPad_PasteByMergedIndex(mergedIndex) {
}
PromptQuickPad_DeleteByMergedIndex(mergedIndex) {
}
PQP_IsReady() {
}
PQP_SendToWeb(payloadJson) {
}

; --- 悬浮栏 / 截图 / 面板（_VK_H 间接调用的宿主函数）---
FloatingToolbarSetChatDrawerState(open) {
}
FloatingToolbar_ActivateSearchCenter() {
}
FloatingToolbarResetScale() {
}
FloatingToolbar_SendTextToNiumaChat(text, activate?, append?, focus?) {
}
FloatingToolbar_SwitchToHoleMode() {
}
FloatingToolbar_SetActivationMode(mode) {
}
FloatingToolbar_ForceRecoverVisible() {
}
FloatingToolbar_DeferredScreenshot() {
}
ShowFloatingToolbar() {
}
MinimizeFloatingToolbarToEdge() {
}
HideFloatingToolbarFromPopupMenu() {
}
ToggleFloatingToolbarFromMenu() {
}
IsScreenshotEditorActive() {
}
ToggleScreenshotEditorAlwaysOnTop() {
}
ExecuteScreenshotOCR() {
}
PasteScreenshotAsText() {
}
SaveScreenshotToFile() {
}
ScreenshotEditorSendToAI() {
}
ScreenshotEditorSearchText() {
}
CloseScreenshotEditor() {
}
