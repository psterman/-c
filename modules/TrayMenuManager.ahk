; TrayMenuManager.ahk — 托盘高分辨率图标、自定义暗色菜单、监听 0x0404（与历史脚本中的 0x404 同值）
; 依赖：主脚本已 #Include lib\Gdip_All.ahk；其余符号（GetText、CleanUp、ExecuteScreenshotWithMenu、ShowSearchCenter、
; FloatingToolbar_*、CP_Show、ShowConfigGUI 等）在运行时至托盘点击时已解析。

global CustomIconPath := ""
global g_LastValidTrayMenu := []
global g_IsUIVisibleTransitioning := false
global g_TrayMenuTransitionToken := 0

; 初始化托盘：清空系统托盘菜单、注册 0x0404、设置图标与提示
TrayMenu_Init() {
    A_TrayMenu.Delete()
    OnMessage(0x0404, TRAY_ICON_MESSAGE)
    TrySetTrayIconHighQuality()
    UpdateTrayMenu()
}

Gdip_CreateTrayHIconFromPngFile(pngPath, size := 256) {
    pBitmap := Gdip_CreateBitmapFromFile(pngPath)
    if !pBitmap
        return 0
    sw := Gdip_GetImageWidth(pBitmap), sh := Gdip_GetImageHeight(pBitmap)
    if (sw < 1 || sh < 1) {
        Gdip_DisposeImage(pBitmap)
        return 0
    }
    pNew := Gdip_CreateBitmap(size, size)
    G := Gdip_GraphicsFromImage(pNew)
    Gdip_SetInterpolationMode(G, 7)
    Gdip_DrawImage(G, pBitmap, 0, 0, size, size, 0, 0, sw, sh)
    Gdip_DeleteGraphics(G)
    Gdip_DisposeImage(pBitmap)
    hIcon := Gdip_CreateHICONFromBitmap(pNew)
    Gdip_DisposeImage(pNew)
    return hIcon
}

TrySetTrayIconHighQuality() {
    global CustomIconPath
    if (IsSet(CustomIconPath) && CustomIconPath != "" && FileExist(CustomIconPath)) {
        if RegExMatch(CustomIconPath, "i)\.png$") {
            try {
                h := Gdip_CreateTrayHIconFromPngFile(CustomIconPath)
                if h {
                    TraySetIcon(h)
                    DllCall("DestroyIcon", "ptr", h)
                    return
                }
            } catch {
            }
        } else {
            try {
                TraySetIcon(CustomIconPath)
                return
            } catch {
            }
        }
    }
    icoNiu := A_ScriptDir "\牛马.ico"
    pngNiu := A_ScriptDir "\牛马.png"
    if FileExist(icoNiu) {
        try {
            TraySetIcon(icoNiu)
            return
        } catch {
        }
    }
    if FileExist(pngNiu) {
        try {
            h := Gdip_CreateTrayHIconFromPngFile(pngNiu)
            if h {
                TraySetIcon(h)
                DllCall("DestroyIcon", "ptr", h)
                return
            }
        } catch {
        }
    }
    chIco := A_ScriptDir "\cursor_helper.ico"
    if FileExist(chIco) {
        try {
            TraySetIcon(chIco)
            return
        } catch {
        }
    }
    if FileExist(A_ScriptDir "\favicon.ico") {
        try TraySetIcon(A_ScriptDir "\favicon.ico")
        catch {
        }
    }
}

ResolveDefaultUiIconPath() {
    global CustomIconPath
    if (IsSet(CustomIconPath) && CustomIconPath != "" && FileExist(CustomIconPath))
        return CustomIconPath
    if FileExist(A_ScriptDir "\牛马.png")
        return A_ScriptDir "\牛马.png"
    return A_ScriptDir "\favicon.ico"
}

UpdateTrayIcon() {
    TrySetTrayIconHighQuality()
}

global TrayMenuGUI := 0
global TrayMenuSelectedItem := 0
global TrayMenuHoverTimer := 0
global TrayMenuPressedItem := 0
global TrayMenuPopupBusy := false
global TrayMenuPopupPending := false
global TrayMenuPopupPendingLParam := 0
global TrayMenuPopupPendingStart := 0

TrayMenu_Log(msg) {
    try {
        logPath := A_ScriptDir . "\Cache\tray_menu_runtime.log"
        dir := ""
        SplitPath(logPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "] " . String(msg) . "`r`n", logPath, "UTF-8")
    } catch {
    }
}

TRAY_ICON_MESSAGE(wParam, lParam, msg, hwnd) {
    global TrayMenuPopupBusy, TrayMenuPopupPending, TrayMenuPopupPendingLParam, TrayMenuPopupPendingStart
    try {
        try TrayMenu_Log("tray_msg lParam=" . lParam . " msg=" . msg)
        if (lParam = 0x203) {
            CleanUp()
            ExitApp()
            return 0
        }
        if (lParam = 0x205 || lParam = 0x202) {
            trayStart := A_TickCount
            searchVisible := false
            gdhoVisible := false
            nativeActive := false
            try searchVisible := SCWV_IsVisible()
            catch {
                searchVisible := false
            }
            try gdhoVisible := GDHO_VISIBLE
            catch {
                gdhoVisible := false
            }
            try nativeActive := NativeDropSessionActive
            catch {
                nativeActive := false
            }
            try TrayMenu_Log("tray_popup_state mode=" . NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (gdhoVisible ? "1" : "0") . " native=" . (nativeActive ? "1" : "0") . " waiting=" . (IsSet(g_SCWV_WaitingUiFinishedReveal) && g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " phase=" . (IsSet(g_SCWV_LifecyclePhase) ? g_SCWV_LifecyclePhase : "") . " caps=" . (GetCapsLockState() ? "1" : "0"))
            catch {
            }
            if (TrayMenuPopupBusy) {
                try TrayMenu_Log("custom_popup_skip_busy lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
                return 0
            }
            TrayMenuPopupBusy := true
            TrayMenuPopupPending := true
            TrayMenuPopupPendingLParam := lParam
            TrayMenuPopupPendingStart := trayStart
            try TrayMenu_Log("custom_popup_queue lParam=" . lParam)
            SetTimer(TrayMenu_ShowQueuedPopup, -1)
            try TrayMenu_Log("custom_popup_return lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
            return 0
        }
    } catch {
    }
}

TrayMenu_ShowQueuedPopup(*) {
    global TrayMenuPopupBusy, TrayMenuPopupPending, TrayMenuPopupPendingLParam, TrayMenuPopupPendingStart
    if !TrayMenuPopupPending
    {
        TrayMenuPopupBusy := false
        return
    }
    lParam := TrayMenuPopupPendingLParam
    trayStart := TrayMenuPopupPendingStart
    TrayMenuPopupPending := false
    try {
        try TrayMenu_Log("custom_popup_begin lParam=" . lParam)
        try {
            ShowCustomTrayMenu()
        } catch as err {
            mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
            try TrayMenu_Log("custom_popup_failed lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart) . " mode=" . mode . " msg=" . err.Message)
            if (mode != "hole") {
                try {
                    TrayMenu_Log("custom_popup_fallback_begin")
                    A_TrayMenu.Show()
                    TrayMenu_Log("custom_popup_fallback_done")
                } catch as fallbackErr {
                    try TrayMenu_Log("custom_popup_fallback_failed msg=" . fallbackErr.Message)
                }
            } else {
                try TrayMenu_Log("custom_popup_fallback_suppressed_hole")
            }
        }
        try TrayMenu_Log("custom_popup_end lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
    } finally {
        TrayMenuPopupBusy := false
    }
}

UpdateTrayMenu() {
    A_IconTip := GetText("app_tip")
    A_TrayMenu.Delete()
    ; Keep a functional fallback menu even if custom dark popup fails.
    A_TrayMenu.Add("搜索中心", ((*) => TrayMenu_RunSceneCmd("tray_show_search")))
    A_TrayMenu.Add("剪贴板", ((*) => TrayMenu_RunSceneCmd("tray_show_clipboard")))
    A_TrayMenu.Add("截图", ((*) => TrayMenu_RunSceneCmd("tray_show_screenshot")))
    A_TrayMenu.Add(GetText("open_config_menu"), ((*) => TrayMenu_RunSceneCmd("tray_show_config")))
    A_TrayMenu.Add()
    A_TrayMenu.Add("重启脚本", ((*) => TrayMenu_RunSceneCmd("tray_reload_script")))
    A_TrayMenu.Add(GetText("exit_menu"), ((*) => TrayMenu_RunSceneCmd("tray_exit_app")))
    A_TrayMenu.Default := "搜索中心"
}

TrayMenuCancelHoverAnim() {
    global TrayMenuHoverTimer
    if (TrayMenuHoverTimer) {
        SetTimer(TrayMenuHoverTimer, 0)
        TrayMenuHoverTimer := 0
    }
}

TrayMenuApplyItemVisual(ItemIndex, state := "idle") {
    global TrayMenuGUI
    if (!TrayMenuGUI || ItemIndex <= 0)
        return
    try {
        bg := TrayPopup_ThemeColor("itemBg")
        accent := bg
        txt := TrayPopup_ThemeColor("text")
        ico := TrayPopup_ThemeColor("icon")
        if (state = "hover") {
            bg := TrayPopup_ThemeColor("hoverBg1")
            accent := TrayPopup_ThemeColor("hoverAccent")
            txt := TrayPopup_ThemeColor("hoverText")
            ico := TrayPopup_ThemeColor("hoverAccent")
        } else if (state = "press") {
            bg := TrayPopup_ThemeColor("activeBg")
            accent := TrayPopup_ThemeColor("activeAccent")
            txt := TrayPopup_ThemeColor("activeText")
            ico := TrayPopup_ThemeColor("activeAccent")
        }
        TrayMenuGUI["MenuItemBg" . ItemIndex].BackColor := bg
        if (TrayMenuGUI.HasProp("MenuItemAccent" . ItemIndex))
            TrayMenuGUI["MenuItemAccent" . ItemIndex].BackColor := accent
        if (TrayMenuGUI.HasProp("MenuItemText" . ItemIndex))
            TrayMenuGUI["MenuItemText" . ItemIndex].SetFont("s11 c" . txt, "DengXian")
        if (TrayMenuGUI.HasProp("MenuItemIcon" . ItemIndex))
            TrayMenuGUI["MenuItemIcon" . ItemIndex].SetFont("s14 c" . ico, "Segoe UI Symbol")
        ; 浅色 + 无主题绘制时，仅改 BackColor 可能不重绘
        gh := 0
        try gh := TrayMenuGUI.Hwnd
        if (gh)
            DllCall("InvalidateRect", "Ptr", gh, "Ptr", 0, "Int", 1)
    } catch {
    }
}

TrayMenuClearSelection() {
    global TrayMenuSelectedItem, TrayMenuPressedItem
    TrayMenuCancelHoverAnim()
    if (TrayMenuPressedItem > 0) {
        TrayMenuApplyItemVisual(TrayMenuPressedItem, "idle")
        TrayMenuPressedItem := 0
    }
    if (TrayMenuSelectedItem > 0) {
        TrayMenuApplyItemVisual(TrayMenuSelectedItem, "idle")
        TrayMenuSelectedItem := 0
    }
}

TrayMenuItemHoverPhase2(ItemIndex, *) {
    global TrayMenuHoverTimer
    TrayMenuHoverTimer := 0
}

TrayMenuItemHover(ItemIndex, *) {
    global TrayMenuSelectedItem, TrayMenuHoverTimer, TrayMenuPressedItem
    if (TrayMenuPressedItem = ItemIndex)
        return
    if (TrayMenuSelectedItem = ItemIndex)
        return
    TrayMenuCancelHoverAnim()
    if (TrayMenuSelectedItem > 0)
        TrayMenuApplyItemVisual(TrayMenuSelectedItem, "idle")
    TrayMenuSelectedItem := ItemIndex
    TrayMenuApplyItemVisual(ItemIndex, "hover")
    TrayMenuHoverTimer := 0
}

TrayMenuItemLeave(ItemIndex, *) {
    global TrayMenuSelectedItem, TrayMenuPressedItem
    if (TrayMenuPressedItem = ItemIndex)
        return
    if (TrayMenuSelectedItem = ItemIndex) {
        TrayMenuApplyItemVisual(ItemIndex, "idle")
        TrayMenuSelectedItem := 0
    }
}

TrayMenuItemPress(ItemIndex) {
    global TrayMenuSelectedItem, TrayMenuPressedItem
    if (ItemIndex <= 0)
        return
    if (TrayMenuSelectedItem > 0 && TrayMenuSelectedItem != ItemIndex)
        TrayMenuApplyItemVisual(TrayMenuSelectedItem, "idle")
    TrayMenuSelectedItem := ItemIndex
    TrayMenuPressedItem := ItemIndex
    TrayMenuApplyItemVisual(ItemIndex, "press")
}

TrayMenuInvokeItem(item, itemIndex, keepOpen := false) {
    global TrayMenuPressedItem
    TrayMenuItemPress(itemIndex)
    Sleep(72)
    if (keepOpen) {
        TrayMenuApplyItemVisual(itemIndex, "hover")
        TrayMenuPressedItem := 0
        return
    }
    CloseDarkStylePopupMenu()
    try TrayMenu_Log("invoke_click idx=" . itemIndex . " text=" . (item.HasProp("Text") ? String(item.Text) : ""))
    try {
        if (item.HasProp("Action") && IsObject(item.Action))
            TrayMenu_InvokeActionDeferred(item.Action, (item.HasProp("Text") ? String(item.Text) : ""))
        try TrayMenu_Log("invoke_ok idx=" . itemIndex . " text=" . (item.HasProp("Text") ? String(item.Text) : ""))
    } catch as err {
        try TrayMenu_Log("invoke_failed idx=" . itemIndex . " msg=" . err.Message)
    } catch {
    }
}

TrayMenu_InvokeActionDeferred(actionObj, actionText := "") {
    SetTimer((*) => TrayMenu_InvokeActionDeferredRun(actionObj, actionText), -1)
}

TrayMenu_InvokeActionDeferredRun(actionObj, actionText := "") {
    Critical "Off"
    try {
        if IsObject(actionObj)
            actionObj.Call()
    } catch as err {
        try TrayMenu_Log("invoke_deferred_failed text=" . actionText . " msg=" . err.Message)
    }
}

TrayMenu_PrepareUiOpenFromHoleMode() {
    global GDHO_VISIBLE, NativeDropSessionActive, g_SCWV_WaitingUiFinishedReveal
    try TrayMenu_Log("prepare_ui_from_hole search_active=" . (IsSearchCenterActive() ? "1" : "0") . " vk_visible=" . (VK_IsHostVisible() ? "1" : "0") . " caps=" . (GetCapsLockState() ? "1" : "0"))
    ; 先跑一次生命周期维护，避免“已关闭但忙碌态残留”的假活状态挡住后续托盘动作。
    try SearchCenter_IsOpeningOrBusy()
    catch {
    }
    ; In hole mode, proactively neutralize overlay hit-test / drag session interference.
    try TrayMenu_HardenHoleUiTransition("tray_open_ui", 1800)
    catch {
    }
    try NormalizeCapsLockRuntimeForUiOpen()
    catch {
    }
    try TrayMenu_Log("prepare_ui_from_hole_done")
}

TrayMenu_WaitForSearchCenterIdle(timeoutMs := 1500) {
    start := A_TickCount
    loop {
        busy := false
        try busy := SearchCenter_IsOpeningOrBusy()
        catch {
            busy := false
        }
        visible := false
        try visible := SCWV_IsVisible()
        catch {
            visible := false
        }
        if (!busy && !visible)
            return true
        if ((A_TickCount - start) >= timeoutMs)
            return false
        Sleep(30)
    }
}

TrayMenu_WaitForHoleUiIdle(timeoutMs := 1800) {
    start := A_TickCount
    loop {
        busy := false
        try busy := SearchCenter_IsOpeningOrBusy()
        catch {
            busy := false
        }
        visible := false
        try visible := SCWV_IsVisible()
        catch {
            visible := false
        }
        gdhoVisible := false
        try gdhoVisible := GDHO_VISIBLE
        catch {
            gdhoVisible := false
        }
        nativeActive := false
        try nativeActive := NativeDropSessionActive
        catch {
            nativeActive := false
        }
        if (!busy && !visible && !gdhoVisible && !nativeActive)
            return true
        if ((A_TickCount - start) >= timeoutMs)
            return false
        Sleep(30)
    }
}

TrayMenu_HardenHoleUiTransition(target := "tray_open_ui", timeoutMs := 1800) {
    Critical "Off"
    global GDHO_VISIBLE, NativeDropSessionActive, g_IsUIVisibleTransitioning, g_TrayMenuTransitionToken
    g_IsUIVisibleTransitioning := true
    g_TrayMenuTransitionToken += 1
    token := g_TrayMenuTransitionToken
    searchVisible := false
    try searchVisible := SCWV_IsVisible()
    catch {
        searchVisible := false
    }
    try TrayMenu_Log("handoff_begin reason=" . target . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (GDHO_VISIBLE ? "1" : "0") . " native=" . (NativeDropSessionActive ? "1" : "0") . " phase=" . (IsSet(g_SCWV_LifecyclePhase) ? g_SCWV_LifecyclePhase : ""))
    catch {
    }

    if (SearchCenter_IsOpeningOrBusy() || IsSearchCenterActive() || searchVisible) {
        try TrayMenu_Log("handoff_step hard_close_search_center_queued reason=" . target)
        SetTimer((*) => TrayMenu_RequestHardCloseSearchCenter(target), -1)
    }

    try TrayMenu_Log("handoff_step clickthrough_begin reason=" . target)
    try GDHO_SetClickThrough(true)
    catch {
    }
    try TrayMenu_Log("handoff_step clickthrough_done reason=" . target)

    try TrayMenu_Log("handoff_step hide_gui_begin reason=" . target)
    try GDHO_Hide()
    catch {
    }
    try TrayMenu_Log("handoff_step hide_gui_done reason=" . target)
    try GDHO_ResetPointerSeed()
    catch {
    }
    SetTimer((*) => TrayMenu_FinalizeHoleUiTransition(target, token), -200)
    try TrayMenu_Log("handoff_queued reason=" . target . " token=" . token . " timeout_ms=" . timeoutMs)
    return true
}

TrayMenu_RequestHardCloseSearchCenter(reason := "") {
    Critical "Off"
    try SCWV_RequestHardClose(reason)
    catch {
    }
}

TrayMenu_FinalizeHoleUiTransition(reason := "", token := 0) {
    Critical "Off"
    global g_IsUIVisibleTransitioning, g_TrayMenuTransitionToken, GDHO_VISIBLE, NativeDropSessionActive
    if (token != g_TrayMenuTransitionToken)
        return
    ; Re-arm the bridge in normal mode so the next UI can keep receiving its normal
    ; initialization and clipboard events.
    try NativeDropBridge_ResetSessionAsync(reason, 0, false)
    catch {
    }
    try GDHO_Hide()
    catch {
    }
    g_IsUIVisibleTransitioning := false
    try TrayMenu_Log("handoff_cleanup_done reason=" . reason . " gdho=" . (GDHO_VISIBLE ? "1" : "0") . " native=" . (NativeDropSessionActive ? "1" : "0"))
    catch {
    }
}

TrayMenu_QueueUiOpenFromHoleMode(actionFn, reason := "") {
    SetTimer((*) => TrayMenu_RunQueuedUiOpenFromHoleMode(actionFn, reason), -1)
}

TrayMenu_RunQueuedUiOpenFromHoleMode(actionFn, reason := "") {
    Critical "Off"
    try TrayMenu_Log("queued_ui_open_begin reason=" . reason)
    TrayMenu_PrepareUiOpenFromHoleMode()
    try TrayMenu_Log("queued_ui_open_after_prep reason=" . reason)
    try {
        if IsObject(actionFn)
            actionFn.Call()
    } catch as err {
        try TrayMenu_Log("queued_ui_open_action_failed reason=" . reason . " msg=" . err.Message)
    }
    try TrayMenu_Log("queued_ui_open_done reason=" . reason)
}

TrayMenu_OpenSearchAction(*) {
    SetTimer((*) => TrayMenu_OpenSearchActionRun(), -1)
}

TrayMenu_OpenSearchActionRun(*) {
    Critical "Off"
    try TrayMenu_Log("open_search_from_menu")
    if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole") {
        try {
            TrayMenu_HardenHoleUiTransition("tray_open_search", 1800)
            if (SearchCenter_IsOpeningOrBusy() || IsSearchCenterActive() || SCWV_IsVisible()) {
                SCWV_RequestHardClose("tray_open_search")
                TrayMenu_WaitForSearchCenterIdle(1500)
            }
        } catch {
        }
        try {
            SCWV_Init("tray_menu_search")
            SCWV_Show("tray_menu_search")
            return
        } catch as err {
            try TrayMenu_Log("open_search_direct_failed msg=" . err.Message)
        }
    }
    if FuncExists("FloatingToolbar_ActivateSearchCenter")
        FloatingToolbar_ActivateSearchCenter()
    else
        ShowSearchCenter()
}

ShowSearchCenterFromMenu(*) {
    SetTimer((*) => ShowSearchCenterFromMenuRun(), -1)
}

ShowSearchCenterFromMenuRun(*) {
    Critical "Off"
    global TrayMenuGUI

    try TrayMenu_Log("show_search_from_menu_begin")
    try {
        if (SCWV_IsVisible() && !SearchCenter_IsOpeningOrBusy()) {
            TrayMenu_Log("show_search_from_menu_toggle_close")
            if (TrayMenuGUI != 0) {
                try {
                    TrayMenuGUI.Destroy()
                    TrayMenuGUI := 0
                    SetTimer(CheckTrayMenuMousePosition, 0)
                }
            }
            try SCWV_RequestHardClose("tray_toggle_search")
            catch {
                try SCWV_Hide(true)
                catch {
                }
            }
            return
        }
        if (SearchCenter_IsOpeningOrBusy()) {
            TrayMenu_Log("show_search_from_menu_busy")
            if (TrayMenuGUI != 0) {
                try {
                    TrayMenuGUI.Destroy()
                    TrayMenuGUI := 0
                    SetTimer(CheckTrayMenuMousePosition, 0)
                }
            }
            if (SCWV_IsVisible()) {
                SCWV_Show("tray_reuse_search")
            } else {
                try SCWV_RequestHardClose("tray_search_busy_reopen")
                catch {
                }
                TrayMenu_WaitForSearchCenterIdle(1500)
                TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenSearchAction, "search_recover")
            }
            return
        }
    } catch {
    }
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenSearchAction, "search")
    try TrayMenu_Log("show_search_from_menu_end")
}

TrayMenu_OpenClipboardAction(*) {
    try TrayMenu_Log("open_clipboard_from_menu")
    CP_Show()
}

TrayMenu_OpenScreenshotAction(*) {
    try TrayMenu_Log("open_screenshot_from_menu")
    ExecuteScreenshotWithMenu()
}

TrayMenu_OpenConfigAction(*) {
    try TrayMenu_Log("open_config_from_menu")
    ShowConfigGUI_Safe()
}

TrayMenu_AddStableCoreItems(MenuItems, mode, ftVis, bubVis) {
    if (mode = "hole") {
        if (bubVis) {
            MenuItems.Push({ Text: "隐藏黑洞", Action: FloatingBubbleHideFromMenu, Icon: "☰" })
        } else {
            MenuItems.Push({ Text: "显示黑洞", Action: FloatingBubbleShowFromMenu, Icon: "☰" })
        }
        return
    }
    if (mode != "tray") {
        if (ftVis) {
            MenuItems.Push({ Text: "隐藏工具栏", Action: ToggleFloatingToolbarFromMenu, Icon: "☰" })
            MenuItems.Push({ Text: "最小化到边缘", Action: MinimizeFloatingToolbarToEdge, Icon: "⊏" })
            MenuItems.Push({ Text: "重置大小", Action: FloatingToolbarResetScale, Icon: "⤢" })
        } else {
            MenuItems.Push({ Text: "显示工具栏", Action: ToggleFloatingToolbarFromMenu, Icon: "☰" })
        }
    }

    MenuItems.Push({ Text: "搜索中心", Action: ShowSearchCenterFromMenu, Icon: "●" })
    MenuItems.Push({ Text: "剪贴板", Action: ShowClipboardFromMenu, Icon: "▤" })
    MenuItems.Push({ Text: "截图", Action: ShowScreenshotFromMenu, Icon: "📷" })
    MenuItems.Push({ Text: GetText("open_config_menu"), Action: ShowConfigFromMenu, Icon: "⚙" })

    if (mode != "tray") {
        MenuItems.Push({ Text: "关闭工具栏", Action: ((*) => TrayMenu_RunSceneCmd("tray_hide_toolbar")), Icon: "◼" })
    }
    MenuItems.Push({ Text: "重启脚本", Action: ((*) => TrayMenu_RunSceneCmd("tray_reload_script")), Icon: "↻" })
    MenuItems.Push({ Text: GetText("exit_menu"), Action: ((*) => TrayMenu_RunSceneCmd("tray_exit_app")), Icon: "✕" })
}

CheckTrayMenuMousePosition(*) {
    global TrayMenuGUI, TrayMenuSelectedItem
    if (!TrayMenuGUI)
        return

    try {
        if (!TrayMenuGUI.HasProp("Hwnd") || !TrayMenuGUI.Hwnd) {
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            return
        }
        if (!WinExist("ahk_id " . TrayMenuGUI.Hwnd)) {
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            return
        }
    } catch {
        TrayMenuGUI := 0
        SetTimer(CheckTrayMenuMousePosition, 0)
        return
    }

    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . TrayMenuGUI.Hwnd)
    } catch {
        TrayMenuGUI := 0
        SetTimer(CheckTrayMenuMousePosition, 0)
        return
    }

    if (MX < WX || MX > WX + WW || MY < WY || MY > WY + WH) {
        TrayMenuClearSelection()
        return
    }

    MenuItemHeight := 35
    Padding := 10
    RelY := MY - WY

    if (RelY < Padding) {
        TrayMenuClearSelection()
        return
    }

    ItemIndex := Floor((RelY - Padding) / MenuItemHeight) + 1
    try {
        if !TrayMenuGUI["MenuItemBg" . ItemIndex]
            return
    } catch {
        return
    }
    ItemY := Padding + (ItemIndex - 1) * MenuItemHeight
    if (RelY >= ItemY && RelY < ItemY + MenuItemHeight) {
        TrayMenuItemHover(ItemIndex)
    } else {
        TrayMenuClearSelection()
    }
}

CloseTrayMenuIfClickedOutside(*) {
    global TrayMenuGUI
    if (TrayMenuGUI != 0) {
        try {
            if (!TrayMenuGUI.HasProp("Hwnd") || !TrayMenuGUI.Hwnd) {
                TrayMenuGUI := 0
                SetTimer(CloseTrayMenuIfClickedOutside, 0)
                SetTimer(CheckTrayMenuMousePosition, 0)
                return
            }
            MouseGetPos(&MX, &MY)
            WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . TrayMenuGUI.Hwnd)
            if (MX < WX || MX > WX + WW || MY < WY || MY > WY + WH) {
                if (GetKeyState("LButton", "P")) {
                    try {
                        TrayMenuGUI.Destroy()
                        TrayMenuGUI := 0
                        SetTimer(CloseTrayMenuIfClickedOutside, 0)
                        SetTimer(CheckTrayMenuMousePosition, 0)
                    }
                }
            }
        } catch {
            TrayMenuGUI := 0
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    } else {
        SetTimer(CloseTrayMenuIfClickedOutside, 0)
        SetTimer(CheckTrayMenuMousePosition, 0)
    }
}

ToggleFloatingToolbarFromMenu(*) {
    global TrayMenuGUI
    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    if (NormalizeAppearanceActivationMode(amRaw) = "hole") {
        try FloatingToolbar_SetActivationMode("toolbar")
    } else {
        ToggleFloatingToolbar()
    }
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }
}

ShowClipboardFromMenu(*) {
    global TrayMenuGUI

    try TrayMenu_Log("show_clipboard_from_menu_begin")
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenClipboardAction, "clipboard")
    try TrayMenu_Log("show_clipboard_from_menu_end")
}

; 截图：modules\ScreenshotWorkflow.ahk — ExecuteScreenshotWithMenu
ShowScreenshotFromMenu(*) {
    global TrayMenuGUI

    try TrayMenu_Log("show_screenshot_from_menu_begin")
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenScreenshotAction, "screenshot")
    try TrayMenu_Log("show_screenshot_from_menu_end")
}

ShowConfigFromMenu(*) {
    global TrayMenuGUI

    try TrayMenu_Log("show_config_from_menu_begin")
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenConfigAction, "config")
    try TrayMenu_Log("show_config_from_menu_end")
}

ExitFromMenu(*) {
    CleanUp()
}

HideFloatingToolbarFromPopupMenu(*) {
    global TrayMenuGUI, AppearanceActivationMode
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        }
    }
    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    if (NormalizeAppearanceActivationMode(amRaw) = "hole") {
        try HideFloatingBubble()
        catch {
        }
    } else {
        HideFloatingToolbar()
    }
}

ReloadScriptFromPopupMenu(*) {
    global TrayMenuGUI, ConfigFile
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        } catch {
        }
    }
    try FloatingToolbarSaveScale()
    catch {
    }
    try SaveFloatingToolbarPosition()
    catch {
    }
    ; 重启前先归一化配置文件编码，避免 ThemeMode 被混写 ini 覆盖
    try _Cfg_NormalizeIniEncoding(ConfigFile)
    catch {
    }
    Reload
}

TrayPopup_GetThemeMode() {
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            t := StrLower(Trim(String(raw)))
            if (t = "light" || t = "lite" || t = "浅色")
                return "light"
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn) {
            t2 := StrLower(Trim(String(fn.Call())))
            if (t2 = "light" || t2 = "lite" || t2 = "浅色")
                return "light"
        }
    } catch {
    }
    try {
        global ThemeMode
        if (IsSet(ThemeMode) && ThemeMode != "") {
            t3 := StrLower(Trim(String(ThemeMode)))
            if (t3 = "light" || t3 = "lite" || t3 = "浅色")
                return "light"
        }
    } catch {
    }
    return "dark"
}

TrayPopup_ThemeColor(key) {
    tm := TrayPopup_GetThemeMode()
    if (tm = "light") {
        mp := Map(
            "menuBg", "f7f7f7",
            "itemBg", "f7f7f7",
            "text", "d35400",
            "icon", "d35400",
            ; 浅色下与 f7f7f7 对比需更明显；文字悬停略加深，避免「看不出动效」
            "hoverBg1", "ffe8cf",
            "hoverBg2", "ffd9a8",
            "hoverText", "a04000",
            "hoverAccent", "d35400",
            "activeBg", "e67e22",
            "activeText", "ffffff",
            "activeAccent", "d66f1a"
        )
    } else {
        mp := Map(
            "menuBg", "1a1a1a",
            "itemBg", "1a1a1a",
            "text", "ff6600",
            "icon", "ff6600",
            "hoverBg1", "2a2622",
            "hoverBg2", "ff6600",
            "hoverText", "ff6600",
            "hoverAccent", "ff8f3a",
            "activeBg", "ff6600",
            "activeText", "ffffff",
            "activeAccent", "ffb36b"
        )
    }
    return mp.Has(key) ? mp[key] : ((tm = "light") ? "f7f7f7" : "1a1a1a")
}

ShowDarkStylePopupMenuAt(MenuItems, posX, posY) {
    global TrayMenuGUI, TrayMenuSelectedItem, TrayMenuPressedItem
    trayShowStart := A_TickCount
    try TrayMenu_Log("dark_popup_show_begin items=" . MenuItems.Length . " pos=" . posX . "," . posY)

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuCancelHoverAnim()
            TrayMenuGUI.Destroy()
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        }
    }

    n := MenuItems.Length
    MenuItemHeight := 35
    Padding := 10
    MenuWidth := 200
    MenuHeight := n * MenuItemHeight + Padding * 2
    cellPad := 4
    cellUseW := MenuWidth - Padding * 2 - cellPad

    vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
    vR := vL + vW, vB := vT + vH
    if (posX < vL + 10) {
        posX := vL + 10
    } else if (posX + MenuWidth > vR - 10) {
        posX := vR - MenuWidth - 10
    }
    if (posY < vT + 10) {
        posY := vT + 10
    } else if (posY + MenuHeight > vB - 10) {
        posY := vB - MenuHeight - 10
    }

    ; -Theme：否则系统视觉主题会盖住 Text 的 Background，淡色下悬停改 BackColor 几乎无变化
    TrayMenuGUI := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale -Theme")
    if !(IsObject(TrayMenuGUI) && TrayMenuGUI) {
        TrayMenuGUI := 0
        return
    }
    menuBg := TrayPopup_ThemeColor("menuBg")
    itemBgColor := TrayPopup_ThemeColor("itemBg")
    textColor := TrayPopup_ThemeColor("text")
    iconColor := TrayPopup_ThemeColor("icon")
    TrayMenuGUI.BackColor := menuBg
    TrayMenuGUI.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background" . menuBg, "")

    TrayMenuSelectedItem := 0
    TrayMenuPressedItem := 0
    IconSize := 16

    ClickHelper(item, itemIndex, *) {
        try {
            keepOpen := (item.HasProp("KeepMenuOpen") && item.KeepMenuOpen)
            TrayMenuInvokeItem(item, itemIndex, keepOpen)
        } catch {
        }
    }

    Loop n {
        Index := A_Index
        Item := MenuItems[Index]
        baseX := Padding
        ItemY := Padding + (Index - 1) * MenuItemHeight
        IconLeftMargin := baseX + 8
        TextLeftMargin := IconLeftMargin + IconSize + 8
        ItemBgCtrl := TrayMenuGUI.Add("Text", "x" . baseX . " y" . ItemY . " w" . cellUseW . " h" . MenuItemHeight . " Background" . itemBgColor . " vMenuItemBg" . Index, "")
        AccentCtrl := TrayMenuGUI.Add("Text", "x" . (baseX + 3) . " y" . (ItemY + 7) . " w3 h" . (MenuItemHeight - 14) . " Background" . itemBgColor . " vMenuItemAccent" . Index, "")
        ItemBgCtrl.OnEvent("Click", ClickHelper.Bind(Item, Index))
        iconFile := ResolveDarkPopupItemIconFile(Item, IconSize)
        if (iconFile != "" && FileExist(iconFile)) {
            IconPic := TrayMenuGUI.Add("Picture", "x" . IconLeftMargin . " y" . (ItemY + ((MenuItemHeight - IconSize) // 2)) . " w" . IconSize . " h" . IconSize . " BackgroundTrans vMenuItemIconPic" . Index, iconFile)
            IconPic.OnEvent("Click", ClickHelper.Bind(Item, Index))
        } else if (Item.HasProp("Icon") && Item.Icon != "") {
            IconText := TrayMenuGUI.Add("Text", "x" . IconLeftMargin . " y" . ItemY . " w" . IconSize . " h" . MenuItemHeight . " Center 0x200 c" . iconColor . " BackgroundTrans vMenuItemIcon" . Index, Item.Icon)
            IconText.SetFont("s14", "Segoe UI Symbol")
            IconText.OnEvent("Click", ClickHelper.Bind(Item, Index))
        }
        tw := cellUseW - (TextLeftMargin - baseX) - 6
        if (tw < 24)
            tw := 24
        ItemText := TrayMenuGUI.Add("Text", "x" . TextLeftMargin . " y" . ItemY . " w" . tw . " h" . MenuItemHeight . " Left 0x200 c" . textColor . " BackgroundTrans vMenuItemText" . Index, Item.Text)
        ItemText.SetFont("s11", "DengXian")
        ItemText.OnEvent("Click", ClickHelper.Bind(Item, Index))
    }

    TrayMenuGUI.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    if (IsObject(TrayMenuGUI) && TrayMenuGUI.HasProp("Hwnd") && TrayMenuGUI.Hwnd) {
        ; 与悬浮工具栏等 +AlwaysOnTop 并存时，仅 AlwaysOnTop 可能仍被压在下方，悬停改色在「看不见」的窗口上
        try {
            DllCall("SetWindowPos", "Ptr", TrayMenuGUI.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x1 | 0x2)  ; HWND_TOPMOST, SWP_NOMOVE|SWP_NOSIZE
        } catch {
        }
        try WinActivate("ahk_id " . TrayMenuGUI.Hwnd)
        catch {
        }
    }
    SetTimer(CheckTrayMenuMousePosition, 50)
    SetTimer(CloseTrayMenuIfClickedOutside, 100)
    try TrayMenu_Log("dark_popup_show_done elapsed_ms=" . (A_TickCount - trayShowStart) . " hwnd=" . (TrayMenuGUI.HasProp("Hwnd") ? TrayMenuGUI.Hwnd : 0))
}

ResolveDarkPopupItemIconFile(Item, size := 18) {
    try {
        if (Item.HasProp("SvgIcon") && Item.SvgIcon != "" && FileExist(Item.SvgIcon)) {
            altPng := RegExReplace(Item.SvgIcon, "\.svg$", ".png")
            if (FileExist(altPng))
                return altPng
            png := EnsureSvgIconRasterized(Item.SvgIcon, size)
            if (png != "" && FileExist(png))
                return png
            return ""
        }
        if (Item.HasProp("IconFile") && Item.IconFile != "" && FileExist(Item.IconFile))
            return Item.IconFile
    } catch {
    }
    return ""
}

EnsureSvgIconRasterized(svgPath, size := 18) {
    try {
        cacheDir := A_ScriptDir "\cache\menu-icons"
        if !DirExist(cacheDir)
            DirCreate(cacheDir)
        baseName := RegExReplace(svgPath, "^.*\\", "")
        key := RegExReplace(baseName, "\.svg$", "")
        themeKey := TrayPopup_GetThemeMode()
        pngPath := cacheDir "\" . key . "_" . size . "_" . themeKey . ".png"

        needRender := !FileExist(pngPath)
        if (!needRender) {
            try {
                svgTime := FileGetTime(svgPath, "M")
                pngTime := FileGetTime(pngPath, "M")
                needRender := (svgTime > pngTime)
            } catch {
                needRender := true
            }
        }

        if (needRender) {
            edge := ResolveHeadlessBrowserForSvg()
            if (edge = "")
                return ""
            url := "file:///" . StrReplace(svgPath, "\", "/")
            bgColor := (TrayPopup_GetThemeMode() = "light") ? "f7f7f7" : "1a1a1a"
            cmd := '"' . edge . '" --headless --disable-gpu --hide-scrollbars --default-background-color=' . bgColor . ' --window-size=' . size . ',' . size . ' --screenshot="' . pngPath . '" "' . url . '"'
            RunWait(cmd, , "Hide")
            if (!FileExist(pngPath))
                return ""
        }
        return pngPath
    } catch {
        return ""
    }
}

ResolveHeadlessBrowserForSvg() {
    static cached := ""
    if (cached != "" && FileExist(cached))
        return cached
    candidates := [
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    ]
    for _, p in candidates {
        if FileExist(p) {
            cached := p
            return cached
        }
    }
    return ""
}

CloseDarkStylePopupMenu(*) {
    global TrayMenuGUI, TrayMenuSelectedItem, TrayMenuPressedItem
    TrayMenuCancelHoverAnim()
    try {
        if (TrayMenuGUI != 0) {
            try TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            TrayMenuSelectedItem := 0
            TrayMenuPressedItem := 0
        }
    } catch {
    }
    SetTimer(CheckTrayMenuMousePosition, 0)
    SetTimer(CloseTrayMenuIfClickedOutside, 0)
}

FloatingBubbleShowFromMenu(*) {
    try FloatingToolbar_SetActivationMode("hole")
    catch {
    }
}

FloatingBubbleHideFromMenu(*) {
    try FloatingToolbar_SetActivationMode("tray")
    catch {
    }
}

TrayMenu_RunSceneCmd(cmdId) {
    SetTimer((*) => TrayMenu_RunSceneCmdRun(cmdId), -1)
}

TrayMenu_RunSceneCmdRun(cmdId) {
    Critical "Off"
    c := Trim(String(cmdId))
    if (c = "")
        return
    try TrayMenu_Log("run_scene_cmd cmd=" . c . " mode=" . NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") . " search_active=" . (IsSearchCenterActive() ? "1" : "0"))
    catch {
    }
    ; Hard route for tray commands: avoid dependency on command-dispatch readiness during startup.
    switch c {
        case "tray_show_search":
            try ShowSearchCenterFromMenu()
            return
        case "tray_show_clipboard":
            try ShowClipboardFromMenu()
            return
        case "tray_show_screenshot":
            try ShowScreenshotFromMenu()
            return
        case "tray_show_config":
            try ShowConfigFromMenu()
            return
        case "tray_toggle_toolbar":
            try ToggleFloatingToolbarFromMenu()
            return
        case "tray_hide_toolbar":
            try HideFloatingToolbarFromPopupMenu()
            return
        case "tray_reload_script":
            try ReloadScriptFromPopupMenu()
            return
        case "tray_exit_app":
            try ExitFromMenu()
            return
    }
    try {
        if IsSet(VK_Execute) {
            ok := VK_Execute(c)
            if ok
                return
        }
    } catch {
        try TrayMenu_Log("run_scene_vk_failed cmd=" . c)
    }
    try {
        if IsSet(_ExecuteCommand)
            _ExecuteCommand(c)
    } catch {
        try TrayMenu_Log("run_scene_exec_failed cmd=" . c)
    }
}

TrayMenu_MakeSceneAction(cmdId) {
    _cid := String(cmdId)
    return ((*) => TrayMenu_RunSceneCmd(_cid))
}

TrayMenu_BuildItemsFromSceneMenu(sceneKey := "tray_menu") {
    global g_Commands, AppearanceActivationMode, g_LastValidTrayMenu
    items := []
    ; Commands are loaded lazily in a few startup paths, so refresh them here before
    ; deciding that the scene menu is unavailable and falling back to the generic menu.
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map)
        return TrayMenu_BuildItemsFromSceneMenuFallback(sceneKey, items)
    if !(g_Commands.Has("SceneMenus") && g_Commands["SceneMenus"] is Map)
        return TrayMenu_BuildItemsFromSceneMenuFallback(sceneKey, items)
    sm := g_Commands["SceneMenus"]
    if !sm.Has(sceneKey) || !(sm[sceneKey] is Array)
        return TrayMenu_BuildItemsFromSceneMenuFallback(sceneKey, items)
    vm := Map()
    if (g_Commands.Has("SceneMenuVisibility") && g_Commands["SceneMenuVisibility"] is Map
        && g_Commands["SceneMenuVisibility"].Has(sceneKey) && g_Commands["SceneMenuVisibility"][sceneKey] is Map)
        vm := g_Commands["SceneMenuVisibility"][sceneKey]
    cmdList := (g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map) ? g_Commands["CommandList"] : Map()
    try {
        rawCount := (sm.Has(sceneKey) && sm[sceneKey] is Array) ? sm[sceneKey].Length : -1
        visCount := IsObject(vm) ? vm.Count : -1
        TrayMenu_Log("scene_items_source scene=" . sceneKey . " mode=" . NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") . " raw_count=" . rawCount . " vis_count=" . visCount . " cmd_count=" . (IsObject(cmdList) ? cmdList.Count : 0))
    } catch {
    }
    items := TrayMenu_BuildItemsFromSceneIds(sm[sceneKey], cmdList, vm)
    try TrayMenu_Log("scene_items_filtered scene=" . sceneKey . " count=" . items.Length)
    catch {
    }
    if (items.Length > 0) {
        try g_LastValidTrayMenu := items.Clone()
        catch {
            g_LastValidTrayMenu := items
        }
        return items
    }
    return TrayMenu_BuildItemsFromSceneMenuFallback(sceneKey, items, cmdList, vm)
}

TrayMenu_BuildItemsFromSceneIds(sceneIds, cmdList, vm := 0) {
    items := []
    seen := Map()
    if !(sceneIds is Array)
        return items
    for cid0 in sceneIds {
        cid := Trim(String(cid0))
        if (cid = "" || seen.Has(cid))
            continue
        seen[cid] := true
        if (IsObject(vm) && vm.Has(cid) && !vm[cid])
            continue
        nm := cid
        if (IsObject(cmdList) && cmdList.Has(cid) && cmdList[cid] is Map && cmdList[cid].Has("name") && cmdList[cid]["name"] != "")
            nm := String(cmdList[cid]["name"])
        if (nm = "" || nm = cid)
            nm := TrayMenu_GetSceneFallbackLabel(cid, nm)
        items.Push({ Text: nm, Action: TrayMenu_MakeSceneAction(cid), Icon: "•" })
    }
    return items
}

TrayMenu_GetSceneFallbackLabel(cmdId, defaultLabel := "") {
    c := Trim(String(cmdId))
    if (c = "")
        return defaultLabel
    switch c {
        case "tray_show_search":
            return "搜索中心"
        case "tray_show_clipboard":
            return "剪贴板"
        case "tray_show_screenshot":
            return "截图"
        case "tray_show_config":
            return "打开配置面板"
        case "tray_toggle_toolbar":
            return "切换工具栏"
        case "tray_hide_toolbar":
            return "关闭工具栏"
        case "tray_reload_script":
            return "重启脚本"
        case "tray_exit_app":
            return "退出工具"
        default:
            return defaultLabel
    }
}

TrayMenu_BuildItemsFromSceneMenuFallback(sceneKey, items := [], cmdList := 0, vm := 0) {
    global AppearanceActivationMode, g_Commands, g_LastValidTrayMenu
    mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    if (sceneKey != "tray_menu" || mode != "hole")
        return items
    if (!(items is Array) || items.Length = 0) {
        try {
            if (IsObject(g_LastValidTrayMenu) && (g_LastValidTrayMenu is Array) && g_LastValidTrayMenu.Length > 0) {
                try TrayMenu_Log("scene_items_fallback_shadow count=" . g_LastValidTrayMenu.Length . " mode=" . mode)
                return g_LastValidTrayMenu.Clone()
            }
        } catch {
        }
    }
    if (!IsObject(cmdList) || !(cmdList is Map) || !cmdList.Count) {
        try {
            if (IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
                cmdList := g_Commands["CommandList"]
        } catch {
        }
    }
    fallbackIds := []
    try fallbackIds := _VK_DefaultSceneMenuTrayMenuCmds()
    catch {
        fallbackIds := []
    }
    if (!(fallbackIds is Array) || fallbackIds.Length = 0)
        return items
    try TrayMenu_Log("scene_items_fallback_default count=" . fallbackIds.Length . " mode=" . mode)
    try {
        hiddenCount := 0
        if (IsObject(vm) && vm is Map) {
            for cid, on in vm {
                if !on
                    hiddenCount += 1
            }
        }
        TrayMenu_Log("scene_items_fallback_context scene=" . sceneKey . " hidden_count=" . hiddenCount . " cmd_count=" . (IsObject(cmdList) ? cmdList.Count : 0))
    } catch {
    }
    return TrayMenu_BuildItemsFromSceneIds(fallbackIds, cmdList, vm)
}

ShowCustomTrayMenu(ItemName := "", ItemPos := "", MyMenu := "") {
    global FloatingToolbarIsVisible, AppearanceActivationMode, FloatingBubbleIsVisible, g_SCWV_WaitingUiFinishedReveal, g_SCWV_CreateInFlight
    global GDHO_VISIBLE, NativeDropSessionActive, g_IsUIVisibleTransitioning
    trayBuildStart := A_TickCount

    MenuWidth := 200
    MenuItemHeight := 35
    Padding := 10
    MenuItems := []

    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    mode := NormalizeAppearanceActivationMode(amRaw)
    ftVis := IsSet(FloatingToolbarIsVisible) ? FloatingToolbarIsVisible : false
    bubVis := IsSet(FloatingBubbleIsVisible) ? FloatingBubbleIsVisible : false
    searchVisible := false
    gdhoVisible := false
    nativeActive := false
    try searchVisible := SCWV_IsVisible()
    catch {
        searchVisible := false
    }
    try gdhoVisible := GDHO_VISIBLE
    catch {
        gdhoVisible := false
    }
    try nativeActive := NativeDropSessionActive
    catch {
        nativeActive := false
    }
    try TrayMenu_Log("custom_popup_state mode=" . mode . " ft_vis=" . (ftVis ? "1" : "0") . " bub_vis=" . (bubVis ? "1" : "0") . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (gdhoVisible ? "1" : "0") . " native=" . (nativeActive ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " create_inflight=" . (g_SCWV_CreateInFlight ? "1" : "0"))
    catch {
    }
    TrayMenu_AddStableCoreItems(MenuItems, mode, ftVis, bubVis)

    sceneItems := []
    if (g_IsUIVisibleTransitioning) {
        Loop 3 {
            if (A_Index > 1)
                Sleep(30)
            sceneItems := TrayMenu_BuildItemsFromSceneMenu("tray_menu")
            if (sceneItems.Length > 0)
                break
        }
    } else {
        sceneItems := TrayMenu_BuildItemsFromSceneMenu("tray_menu")
    }
    try TrayMenu_Log("custom_popup_scene_items count=" . sceneItems.Length . " mode=" . mode)
    catch {
    }
    if (sceneItems.Length > 0) {
        ; 黑洞模式也沿用悬浮栏的 scene menu 内容，避免菜单在 hole 运行态被主动降级。
        ; 真正的安全收敛交给各个 action 自己的异步打开/硬关闭逻辑。
        try TrayMenu_Log("scene_items_appended count=" . sceneItems.Length . " mode=" . mode)
        for it in sceneItems
            MenuItems.Push(it)
    }

    MenuHeight := MenuItems.Length * MenuItemHeight + Padding * 2
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    posX := mX - (MenuWidth // 2)
    posY := mY - MenuHeight - 10

    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if (posX < 10) {
        posX := 10
    } else if (posX + MenuWidth > ScreenWidth - 10) {
        posX := ScreenWidth - MenuWidth - 10
    }
    if (posY < 10) {
        posY := mY + 10
    } else if (posY + MenuHeight > ScreenHeight - 10) {
        posY := ScreenHeight - MenuHeight - 10
    }

    ; Stability fallback: disable icon glyphs to avoid font/icon rendering glitches.
    try {
        for _, it in MenuItems {
            if (it is Map && it.Has("Icon"))
                it["Icon"] := ""
        }
    } catch {
    }
    try TrayMenu_Log("custom_popup_build_done items=" . MenuItems.Length . " elapsed_ms=" . (A_TickCount - trayBuildStart))
    ShowDarkStylePopupMenuAt(MenuItems, posX, posY)
}
