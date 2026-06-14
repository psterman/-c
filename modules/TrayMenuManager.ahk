; TrayMenuManager.ahk — 托盘高分辨率图标、自定义暗色菜单、监听 0x0404（与历史脚本中的 0x404 同值）
; 依赖：主脚本已 #Include lib\Gdip_All.ahk；其余符号（GetText、CleanUp、ExecuteScreenshotWithMenu、ShowSearchCenter、
; FloatingToolbar_*、CP_Show、ShowConfigGUI 等）在运行时至托盘点击时已解析。

global CustomIconPath := ""
global g_LastValidTrayMenu := []
global g_TrayMenuSceneSnapshot := Map()
global g_TrayMenuSceneDirty := true
global g_TrayMenuSceneRebuildQueued := false
global g_TrayMenuSceneRebuildBusy := false
global g_TrayMenuSceneSnapshotTick := 0
global g_IsUIVisibleTransitioning := false
global g_TrayMenuTransitionToken := 0
global g_TrayMenuTransitionStartTick := 0
global g_TraySvgRenderInFlight := Map()
global TrayMenuCustomFailStreak := 0
global TrayMenuSuppressNativeFallbackUntil := 0

; 初始化托盘：清空系统托盘菜单、注册 0x0404、设置图标与提示
TrayMenu_Init() {
    A_TrayMenu.Delete()
    OnMessage(0x0404, TRAY_ICON_MESSAGE)
    TrySetTrayIconHighQuality()
    UpdateTrayMenu()
    TrayMenu_MarkSceneDirty("init")
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
    icoNiu := Nmer_AppIconIcoPath()
    pngNiu := Nmer_AppIconPngPath()
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
    if FileExist(Nmer_AppIconPngPath())
        return Nmer_AppIconPngPath()
    if FileExist(Nmer_AppIconIcoPath())
        return Nmer_AppIconIcoPath()
    chIco := A_ScriptDir "\cursor_helper.ico"
    if FileExist(chIco)
        return chIco
    return A_ScriptDir "\favicon.ico"
}

UpdateTrayIcon() {
    TrySetTrayIconHighQuality()
}

global g_NmerAppToastGui := 0
global g_NmerAppToastTitle := 0
global g_NmerAppToastBody := 0
global g_NmerAppToastPic := 0
global g_NmerAppToastHideSerial := 0

Nmer_PrepareToastIconPath(targetPx := 96) {
    src := ResolveDefaultUiIconPath()
    if !FileExist(src)
        return ""
    if !RegExMatch(src, "i)\.(png|ico|bmp)$")
        return src
    if !FuncExists("Gdip_CreateBitmapFromFile")
        return src
    dest := A_Temp "\nmer_toast_icon_" . targetPx . ".png"
    try {
        if FileExist(dest)
            FileDelete(dest)
    } catch {
    }
    pBitmap := 0
    pNew := 0
    G := 0
    try {
        pBitmap := Gdip_CreateBitmapFromFile(src)
        if !pBitmap
            return src
        sw := Gdip_GetImageWidth(pBitmap), sh := Gdip_GetImageHeight(pBitmap)
        if (sw < 1 || sh < 1)
            return src
        pNew := Gdip_CreateBitmap(targetPx, targetPx)
        G := Gdip_GraphicsFromImage(pNew)
        Gdip_SetInterpolationMode(G, 7)
        Gdip_SetSmoothingMode(G, 4)
        Gdip_DrawImage(G, pBitmap, 0, 0, targetPx, targetPx, 0, 0, sw, sh)
        Gdip_SaveBitmapToFile(pNew, dest, 100)
        return FileExist(dest) ? dest : src
    } catch {
        return src
    } finally {
        if G
            try Gdip_DeleteGraphics(G)
            catch {
            }
        if pNew
            try Gdip_DisposeImage(pNew)
            catch {
            }
        if pBitmap
            try Gdip_DisposeImage(pBitmap)
            catch {
            }
    }
}

Nmer_ShowAppToast(heading, body, severity := "info") {
    global g_NmerAppToastGui, g_NmerAppToastTitle, g_NmerAppToastBody, g_NmerAppToastPic, g_NmerAppToastHideSerial
    heading := String(heading || "")
    body := String(body || "")
    sev := StrLower(String(severity || "info"))
    accent := (sev = "error" || sev = "warn") ? "f87171" : (sev = "ok" ? "4ade80" : "ff8d2a")
    iconPath := Nmer_PrepareToastIconPath(96)
    if !g_NmerAppToastGui {
        g_NmerAppToastGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "牛马")
        g_NmerAppToastGui.BackColor := "1a1f28"
        g_NmerAppToastGui.MarginX := 12
        g_NmerAppToastGui.MarginY := 10
        if (iconPath != "" && FileExist(iconPath))
            g_NmerAppToastPic := g_NmerAppToastGui.Add("Picture", "x12 y12 w48 h48", iconPath)
        g_NmerAppToastTitle := g_NmerAppToastGui.Add(
            "Text",
            "x68 y12 w300 BackgroundTrans c" . accent,
            ""
        )
        g_NmerAppToastTitle.SetFont("s11 Bold", "Segoe UI")
        g_NmerAppToastBody := g_NmerAppToastGui.Add("Text", "x68 y36 w300 +Wrap BackgroundTrans cE8EDF2", "")
        g_NmerAppToastBody.SetFont("s9", "Segoe UI")
    } else if (iconPath != "" && FileExist(iconPath) && g_NmerAppToastPic) {
        try g_NmerAppToastPic.Value := iconPath
        catch {
        }
    }
    g_NmerAppToastTitle.Opt("c" . accent)
    g_NmerAppToastTitle.Value := heading
    g_NmerAppToastBody.Value := body
    g_NmerAppToastGui.Show("AutoSize Hide")
    wl := 0, wt := 0, wr := A_ScreenWidth, wb := A_ScreenHeight
    try MonitorGetWorkArea(, &wl, &wt, &wr, &wb)
    catch {
    }
    g_NmerAppToastGui.GetPos(, , &tw, &th)
    tx := wr - tw - 16
    ty := wb - th - 16
    if (tx < wl + 8)
        tx := wl + 8
    if (ty < wt + 8)
        ty := wt + 8
    g_NmerAppToastGui.Show("x" . tx . " y" . ty . " NoActivate")
    g_NmerAppToastHideSerial += 1
    serial := g_NmerAppToastHideSerial
    SetTimer(Nmer_HideAppToast.Bind(serial), -5000)
}

Nmer_HideAppToast(serial, *) {
    global g_NmerAppToastGui, g_NmerAppToastHideSerial
    if (serial != g_NmerAppToastHideSerial)
        return
    try {
        if g_NmerAppToastGui
            g_NmerAppToastGui.Hide()
    } catch {
    }
}

global TrayMenuGUI := 0
global TrayMenuSelectedItem := 0
global TrayMenuHoverTimer := 0
global TrayMenuPressedItem := 0
global TrayMenuPopupBusy := false
global TrayMenuPopupPending := false
global TrayMenuPopupPendingLParam := 0
global TrayMenuPopupPendingStart := 0
global TrayMenuPopupBusySince := 0
global g_TrayMenuSuppressOpenUntil := 0
global g_TrayShowHolePending := false
global g_TrayShowHoleRetryCount := 0
global g_TrayShowHolePendingSince := 0
global g_TrayHoleInputPanelVisible := true
global g_TrayHolePanelPassthrough := false

TrayMenu_Log(msg) {
    try {
        logPath := Nmer_DebugPath("tray_menu_runtime.log")
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" . ts . "] " . String(msg) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(logPath, line)
        else
            FileAppend(line, logPath, "UTF-8")
    } catch {
    }
}

TRAY_ICON_MESSAGE(wParam, lParam, msg, hwnd) {
    global TrayMenuPopupBusy, TrayMenuPopupPending, TrayMenuPopupPendingLParam, TrayMenuPopupPendingStart, TrayMenuPopupBusySince
    global g_TrayMenuSuppressOpenUntil, g_GDHO_CurrentPhase, g_GDHO_CurrentToken
    try {
        if (g_TrayMenuSuppressOpenUntil > A_TickCount && (lParam = 0x205 || lParam = 0x202)) {
            try TrayMenu_Log("tray_popup_suppressed lParam=" . lParam . " remain_ms=" . (g_TrayMenuSuppressOpenUntil - A_TickCount))
            return 0
        }
        ; Throttle noisy mouse-move tray events to avoid IO-induced lag/degrade.
        if (lParam != 0x200)
            try TrayMenu_Log("tray_msg lParam=" . lParam . " msg=" . msg)
        if (lParam = 0x203) {
            ; Keep behavior aligned with toolbar mode: double-click opens default tray action.
            try TrayMenu_Log("tray_dblclick default_action=tray_show_search")
            TrayMenu_RunSceneCmd("tray_show_search")
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
            try TrayMenu_Log("tray_popup_state mode=" . NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (gdhoVisible ? "1" : "0") . " gdho_phase=" . (IsSet(g_GDHO_CurrentPhase) ? g_GDHO_CurrentPhase : "") . " gdho_token=" . (IsSet(g_GDHO_CurrentToken) ? g_GDHO_CurrentToken : 0) . " native=" . (nativeActive ? "1" : "0") . " waiting=" . (IsSet(g_SCWV_WaitingUiFinishedReveal) && g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " phase=" . (IsSet(g_SCWV_LifecyclePhase) ? g_SCWV_LifecyclePhase : "") . " caps=" . (GetCapsLockState() ? "1" : "0"))
            catch {
            }
            if (TrayMenuPopupBusy) {
                if (TrayMenuPopupBusySince > 0 && (A_TickCount - TrayMenuPopupBusySince) > 2500) {
                    TrayMenuPopupBusy := false
                    TrayMenuPopupPending := false
                    TrayMenuPopupBusySince := 0
                    try TrayMenu_Log("custom_popup_busy_watchdog_release elapsed_ms=" . (A_TickCount - trayStart))
                } else {
                try TrayMenu_Log("custom_popup_skip_busy lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
                return 0
                }
            }
            TrayMenuPopupBusy := true
            TrayMenuPopupBusySince := A_TickCount
            TrayMenuPopupPending := true
            TrayMenuPopupPendingLParam := lParam
            TrayMenuPopupPendingStart := trayStart
            try TrayMenu_Log("custom_popup_queue lParam=" . lParam)
            SetTimer(TrayMenu_ShowQueuedPopup, -10)
            try TrayMenu_Log("custom_popup_return lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
            return 0
        }
    } catch {
    }
}

TrayMenu_ShowQueuedPopup(*) {
    global TrayMenuPopupBusy, TrayMenuPopupPending, TrayMenuPopupPendingLParam, TrayMenuPopupPendingStart, TrayMenuPopupBusySince
    global TrayMenuCustomFailStreak, TrayMenuSuppressNativeFallbackUntil
    if !TrayMenuPopupPending
    {
        TrayMenuPopupBusy := false
        TrayMenuPopupBusySince := 0
        return
    }
    lParam := TrayMenuPopupPendingLParam
    trayStart := TrayMenuPopupPendingStart
    TrayMenuPopupPending := false
    try {
        try TrayMenu_Log("custom_popup_begin lParam=" . lParam)
        try {
            ShowCustomTrayMenu()
            TrayMenuCustomFailStreak := 0
        } catch as err {
            mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
            try TrayMenu_Log("custom_popup_failed lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart) . " mode=" . mode . " msg=" . err.Message)
            if (mode = "hole") {
                try TrayMenu_ForceBreakSearchCenterStuck("tray_popup_failed")
                try TrayMenu_Log("custom_popup_recover_retry mode=hole")
                TrayMenuCustomFailStreak := 0
                TrayMenuSuppressNativeFallbackUntil := A_TickCount + 60000
                SetTimer(TrayMenu_ShowQueuedPopup, -180)
                TrayMenuPopupPending := true
                TrayMenuPopupPendingLParam := lParam
                TrayMenuPopupPendingStart := trayStart
                return
            }
            TrayMenuCustomFailStreak += 1
            nowTick := A_TickCount
            ; Non-hole mode can still fall back to native tray menu.
            if (TrayMenuCustomFailStreak <= 2 || nowTick < TrayMenuSuppressNativeFallbackUntil) {
                TrayMenuSuppressNativeFallbackUntil := nowTick + 1800
                try TrayMenu_Log("custom_popup_retry_dark streak=" . TrayMenuCustomFailStreak . " mode=" . mode)
                SetTimer(TrayMenu_ShowQueuedPopup, -120)
                TrayMenuPopupPending := true
                TrayMenuPopupPendingLParam := lParam
                TrayMenuPopupPendingStart := trayStart
                return
            }
            if (mode = "hole") {
                TrayMenuCustomFailStreak := 0
                TrayMenuSuppressNativeFallbackUntil := nowTick + 2500
                try TrayMenu_Log("custom_popup_no_native_fallback mode=hole")
                return
            }
            ; Keep dark custom menu path only. Native fallback turns into white menu
            ; and breaks visual/behavior consistency after repeated failures.
            try TrayMenu_Log("custom_popup_native_fallback_disabled mode=" . mode . " streak=" . TrayMenuCustomFailStreak)
            try TrayMenu_ForceBreakSearchCenterStuck("custom_popup_retry_only")
            TrayMenuCustomFailStreak := 0
            TrayMenuSuppressNativeFallbackUntil := nowTick + 3000
            SetTimer(TrayMenu_ShowQueuedPopup, -180)
            TrayMenuPopupPending := true
            TrayMenuPopupPendingLParam := lParam
            TrayMenuPopupPendingStart := trayStart
            return
        }
        try TrayMenu_Log("custom_popup_end lParam=" . lParam . " elapsed_ms=" . (A_TickCount - trayStart))
    } finally {
        TrayMenuPopupBusy := false
        TrayMenuPopupBusySince := 0
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
    A_TrayMenu.Add("彻底退出重启", ((*) => TrayMenu_RunSceneCmd("tray_restart_clean")))
    A_TrayMenu.Add("[!] 强制重置搜索中心", ((*) => TrayMenu_RunSceneCmd("tray_force_reinit_search")))
    A_TrayMenu.Add(GetText("exit_menu"), ((*) => TrayMenu_RunSceneCmd("tray_exit_app")))
    A_TrayMenu.Default := "搜索中心"
    TrayMenu_MarkSceneDirty("update_tray_menu")
}

TrayMenu_MarkSceneDirty(reason := "") {
    global g_TrayMenuSceneDirty
    g_TrayMenuSceneDirty := true
    try TrayMenu_Log("snapshot_dirty reason=" . reason)
    TrayMenu_ScheduleSceneSnapshotRebuild(120)
}

TrayMenu_NotifyCommandsChanged(reason := "commands_changed") {
    TrayMenu_MarkSceneDirty(reason)
}

TrayMenu_ScheduleSceneSnapshotRebuild(delayMs := 80) {
    global g_TrayMenuSceneRebuildQueued
    if g_TrayMenuSceneRebuildQueued
        return
    g_TrayMenuSceneRebuildQueued := true
    SetTimer(TrayMenu_RebuildSceneSnapshot, -Abs(Integer(delayMs)))
}

TrayMenu_RebuildSceneSnapshot(*) {
    global g_TrayMenuSceneRebuildQueued, g_TrayMenuSceneRebuildBusy, g_TrayMenuSceneSnapshot, g_TrayMenuSceneDirty, g_TrayMenuSceneSnapshotTick
    global g_LastValidTrayMenu
    g_TrayMenuSceneRebuildQueued := false
    if g_TrayMenuSceneRebuildBusy
        return
    g_TrayMenuSceneRebuildBusy := true
    try {
        t0 := A_TickCount
        liveItems := TrayMenu_BuildItemsFromSceneMenuLive("tray_menu", false)
        if (!(liveItems is Array) || liveItems.Length = 0)
            liveItems := TrayMenu_BuildItemsFromSceneMenuLive("tray_menu", true)
        snap := []
        if (liveItems is Array && liveItems.Length > 0) {
            for it in liveItems {
                cmdId := ""
                text := ""
                icon := "•"
                try cmdId := it.HasProp("CmdId") ? String(it.CmdId) : ""
                try text := it.HasProp("Text") ? String(it.Text) : ""
                try icon := (it.HasProp("Icon") && it.Icon != "") ? String(it.Icon) : "•"
                if (cmdId = "" || text = "")
                    continue
                snap.Push(Map("cmdId", cmdId, "text", text, "icon", icon))
            }
        }
        if (snap.Length > 0) {
            g_TrayMenuSceneSnapshot["tray_menu"] := snap
            g_TrayMenuSceneDirty := false
            g_TrayMenuSceneSnapshotTick := A_TickCount
            try TrayMenu_Log("snapshot_rebuild_ok count=" . snap.Length . " elapsed_ms=" . (A_TickCount - t0))
        } else {
            ; Keep previous snapshot; fall back to last valid live items when needed.
            try TrayMenu_Log("snapshot_rebuild_empty elapsed_ms=" . (A_TickCount - t0))
            if (g_LastValidTrayMenu is Array && g_LastValidTrayMenu.Length > 0)
                g_TrayMenuSceneDirty := false
        }
    } catch as err {
        try TrayMenu_Log("snapshot_rebuild_failed msg=" . err.Message)
    } finally {
        g_TrayMenuSceneRebuildBusy := false
    }
}

TrayMenu_GetSceneItemsFromSnapshot(sceneKey := "tray_menu") {
    global g_TrayMenuSceneSnapshot, g_TrayMenuSceneDirty, g_LastValidTrayMenu
    items := []
    if g_TrayMenuSceneDirty
        TrayMenu_ScheduleSceneSnapshotRebuild(10)
    if (g_TrayMenuSceneSnapshot is Map && g_TrayMenuSceneSnapshot.Has(sceneKey) && g_TrayMenuSceneSnapshot[sceneKey] is Array) {
        raw := g_TrayMenuSceneSnapshot[sceneKey]
        if (raw.Length > 0) {
            try TrayMenu_Log("snapshot_hit scene=" . sceneKey . " count=" . raw.Length)
            for ent in raw {
                cmdId := ent.Has("cmdId") ? String(ent["cmdId"]) : ""
                text := ent.Has("text") ? String(ent["text"]) : ""
                icon := ent.Has("icon") ? String(ent["icon"]) : "•"
                if (cmdId = "" || text = "")
                    continue
                items.Push({ Text: text, Action: TrayMenu_MakeSceneAction(cmdId), Icon: icon, CmdId: cmdId })
            }
            if (items.Length > 0)
                return items
        }
    }
    try TrayMenu_Log("snapshot_miss scene=" . sceneKey . " dirty=" . (g_TrayMenuSceneDirty ? "1" : "0"))
    if (g_LastValidTrayMenu is Array && g_LastValidTrayMenu.Length > 0) {
        try return g_LastValidTrayMenu.Clone()
        catch {
            return g_LastValidTrayMenu
        }
    }
    return items
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
    global TrayMenuPressedItem, g_TrayMenuSuppressOpenUntil
    TrayMenuItemPress(itemIndex)
    if (keepOpen) {
        TrayMenuApplyItemVisual(itemIndex, "hover")
        TrayMenuPressedItem := 0
        return
    }
    CloseDarkStylePopupMenu()
    TrayMenu_ResetPopupState("invoke_click")
    ; A tray click can emit another WM_RBUTTONUP shortly after invoke.
    ; Suppress one short window to avoid immediate popup reentry/stuck menu.
    g_TrayMenuSuppressOpenUntil := A_TickCount + 520
    SetTimer((*) => TrayMenu_ResetPopupState("invoke_click_deferred_1"), -120)
    SetTimer((*) => TrayMenu_ResetPopupState("invoke_click_deferred_2"), -380)
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
    SetTimer((*) => TrayMenu_InvokeActionDeferredRun(actionObj, actionText), -10)
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

TrayMenu_ForceBreakSearchCenterStuck(reason := "tray_force_break") {
    ; Force-clear stuck SearchCenter lifecycle before critical tray actions
    ; like open-config / exit in hole mode.
    try TrayMenu_Log("force_break_begin reason=" . reason)
    ; Avoid synchronous hard-close on tray callback thread.
    ; In some stale lifecycle states this can block and prevent resume/silent-off.
    try SetTimer((*) => SCWV_RequestHardClose(reason), -10)
    catch {
        try SetTimer((*) => SCWV_SubmitIntent("close", 15, Map("reason", reason . "_fallback_close")), -10)
        catch {
        }
    }
    try SetTimer((*) => SCWV_RequestHardClose(reason . "_retry"), -80)
    catch {
    }
    try SetTimer((*) => SCWV_RequestHardClose(reason . "_retry2"), -220)
    catch {
    }
    try NativeDropBridge_ResetSessionAsync(reason, 0, true)
    catch {
    }
    try SetTimer((*) => TrayMenu_HideHoleOverlayAsync(reason . "_finalize"), -10)
    catch {
    }
    ; Re-enable native drop bridge after forced break, otherwise text selection drag
    ; may stay in silent mode and never reveal hole overlay.
    try SetTimer((*) => NativeDropBridge_SetSilentMode(false, reason . "_resume"), -260)
    catch {
    }
    try TrayMenu_Log("force_break_end reason=" . reason)
}

TrayMenu_WaitForSearchCenterIdle(timeoutMs := 1500) {
    ; Non-blocking legacy compatibility wrapper.
    ; Do not spin/sleep on UI thread: just schedule async force-break fallback.
    try TrayMenu_Log("wait_search_idle_async timeout_ms=" . timeoutMs)
    try SetTimer((*) => TrayMenu_ForceBreakSearchCenterStuck("wait_search_idle_async_timeout"), -Abs(Integer(timeoutMs)))
    catch {
    }
    return false
}

TrayMenu_WaitForHoleUiIdle(timeoutMs := 1800) {
    ; Non-blocking legacy compatibility wrapper.
    try TrayMenu_Log("wait_hole_idle_async timeout_ms=" . timeoutMs)
    try SetTimer((*) => TrayMenu_HideHoleOverlayAsync("wait_hole_idle_async_timeout"), -Abs(Integer(timeoutMs)))
    catch {
    }
    return false
}

TrayMenu_HardenHoleUiTransition(target := "tray_open_ui", timeoutMs := 1800) {
    Critical "Off"
    global GDHO_VISIBLE, NativeDropSessionActive, g_IsUIVisibleTransitioning, g_TrayMenuTransitionToken, g_TrayMenuTransitionStartTick
    global g_GDHO_CurrentPhase, g_GDHO_CurrentToken
    isSearchOpen := (target = "tray_open_search" || target = "caps_f_search" || target = "search" || target = "hole_search_commit")
    g_IsUIVisibleTransitioning := true
    g_TrayMenuTransitionToken += 1
    g_TrayMenuTransitionStartTick := A_TickCount
    token := g_TrayMenuTransitionToken
    searchVisible := false
    try searchVisible := SCWV_IsVisible()
    catch {
        searchVisible := false
    }
    try TrayMenu_Log("handoff_begin reason=" . target . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (GDHO_VISIBLE ? "1" : "0") . " gdho_phase=" . (IsSet(g_GDHO_CurrentPhase) ? g_GDHO_CurrentPhase : "") . " gdho_token=" . (IsSet(g_GDHO_CurrentToken) ? g_GDHO_CurrentToken : 0) . " native=" . (NativeDropSessionActive ? "1" : "0") . " phase=" . (IsSet(g_SCWV_LifecyclePhase) ? g_SCWV_LifecyclePhase : ""))
    catch {
    }

    if (!isSearchOpen && (SearchCenter_IsOpeningOrBusy() || IsSearchCenterActive() || searchVisible)) {
        try TrayMenu_Log("handoff_step hard_close_search_center_queued reason=" . target)
        SetTimer((*) => TrayMenu_RequestHardCloseSearchCenter(target), -10)
    }

    try TrayMenu_Log("handoff_step clickthrough_begin reason=" . target)
    try GDHO_SetClickThrough(true)
    catch {
    }
    try TrayMenu_Log("handoff_step clickthrough_done reason=" . target)

    try TrayMenu_Log("handoff_step hide_gui_queue reason=" . target)
    try SetTimer((*) => TrayMenu_HideHoleOverlayAsync(target), -10)
    catch {
    }
    try GDHO_ResetPointerSeed()
    catch {
    }
    SetTimer((*) => TrayMenu_FinalizeHoleUiTransition(target, token), -200)
    SetTimer((*) => TrayMenu_TransitionWatchdog(token), -2200)
    try TrayMenu_Log("handoff_queued reason=" . target . " token=" . token . " timeout_ms=" . timeoutMs)
    return true
}

TrayMenu_TransitionWatchdog(token := 0) {
    global g_IsUIVisibleTransitioning, g_TrayMenuTransitionToken, g_TrayMenuTransitionStartTick
    if !g_IsUIVisibleTransitioning
        return
    if (token && token != g_TrayMenuTransitionToken)
        return
    elapsed := A_TickCount - g_TrayMenuTransitionStartTick
    if (elapsed < 2000)
        return
    g_IsUIVisibleTransitioning := false
    g_TrayMenuTransitionStartTick := 0
    try TrayMenu_Log("handoff_watchdog_release token=" . g_TrayMenuTransitionToken . " elapsed_ms=" . elapsed)
}

TrayMenu_RequestHardCloseSearchCenter(reason := "") {
    Critical "Off"
    try SCWV_RequestHardClose(reason)
    catch {
    }
}

TrayMenu_HideHoleOverlayAsync(reason := "") {
    Critical "Off"
    global NativeDropSessionActive
    try TrayMenu_Log("handoff_step hide_gui_async_begin reason=" . reason)
    try GDHO_RequestClose(reason)
    catch {
    }
    try NativeDropSessionActive := false
    try TrayMenu_Log("handoff_step hide_gui_async_done reason=" . reason)
}

TrayMenu_FinalizeHoleUiTransition(reason := "", token := 0) {
    Critical "Off"
    global g_IsUIVisibleTransitioning, g_TrayMenuTransitionToken, g_TrayMenuTransitionStartTick, GDHO_VISIBLE, NativeDropSessionActive
    global g_GDHO_CurrentPhase, g_GDHO_CurrentToken
    if (token != g_TrayMenuTransitionToken) {
        try TrayMenu_Log("handoff_finalize_skip_stale reason=" . reason . " token=" . token . " current=" . g_TrayMenuTransitionToken)
        return
    }
    ; Re-arm the bridge in normal mode so the next UI can keep receiving its normal
    ; initialization and clipboard events.
    try NativeDropBridge_ResetSessionAsync(reason, 0, false)
    catch {
    }
    try SetTimer((*) => TrayMenu_HideHoleOverlayAsync(reason . "_finalize"), -10)
    catch {
    }
    g_IsUIVisibleTransitioning := false
    g_TrayMenuTransitionStartTick := 0
    try TrayMenu_Log("handoff_cleanup_done reason=" . reason . " gdho=" . (GDHO_VISIBLE ? "1" : "0") . " gdho_phase=" . (IsSet(g_GDHO_CurrentPhase) ? g_GDHO_CurrentPhase : "") . " gdho_token=" . (IsSet(g_GDHO_CurrentToken) ? g_GDHO_CurrentToken : 0) . " native=" . (NativeDropSessionActive ? "1" : "0"))
    catch {
    }
}

TrayMenu_QueueUiOpenFromHoleMode(actionFn, reason := "") {
    SetTimer((*) => TrayMenu_RunQueuedUiOpenFromHoleMode(actionFn, reason), -10)
}

TrayMenu_RunQueuedUiOpenFromHoleMode(actionFn, reason := "") {
    Critical "Off"
    try TrayMenu_Log("queued_ui_open_begin reason=" . reason)
    if (reason = "search")
        TrayMenu_PrepareSearchOpenFromHoleMode()
    else
        TrayMenu_PrepareUiOpenFromHoleMode()
    ; Zero-blocking tray policy: never wait synchronously for SCWV/hole state.
    ; Any lifecycle resolution happens asynchronously via SCWV intents.
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
    SetTimer((*) => TrayMenu_OpenSearchActionRun(), -10)
}

TrayMenu_OpenSearchActionRun(*) {
    Critical "Off"
    global g_SCWV_TrayOpenLock, g_SCWV_TrayOpenLockTick
    if (g_SCWV_TrayOpenLock) {
        elapsed := A_TickCount - g_SCWV_TrayOpenLockTick
        if (elapsed < 1200) {
            try TrayMenu_Log("open_search_lock_skip elapsed_ms=" . elapsed)
            return
        }
        ; 超时降级：锁意外残留时自动释放，避免“点不开”。
        g_SCWV_TrayOpenLock := false
        try TrayMenu_Log("open_search_lock_force_release elapsed_ms=" . elapsed)
    }
    g_SCWV_TrayOpenLock := true
    g_SCWV_TrayOpenLockTick := A_TickCount
    SetTimer((*) => TrayMenu_OpenSearchLockWatchdog(), -1600)
    try TrayMenu_Log("open_search_from_menu")
    try {
        if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole") {
            try {
                SurfaceIntent_OpenSearch("", "search_hotkey")
                return
            } catch as err {
                try TrayMenu_Log("open_search_direct_failed msg=" . err.Message)
            }
        }
        ; Non-hole path also use robust init+show instead of mixed entry points.
        try {
            SurfaceIntent_OpenSearch("", "search_hotkey")
            return
        } catch as err2 {
            try TrayMenu_Log("open_search_fallback_failed msg=" . err2.Message)
        }
        if FuncExists("FloatingToolbar_ActivateSearchCenter")
            FloatingToolbar_ActivateSearchCenter()
        else
            ShowSearchCenter()
    } finally {
        g_SCWV_TrayOpenLock := false
        g_SCWV_TrayOpenLockTick := 0
    }
}

TrayMenu_PrepareSearchOpenFromHoleMode() {
    try TrayMenu_Log("prepare_search_from_hole search_active=" . (IsSearchCenterActive() ? "1" : "0") . " caps=" . (GetCapsLockState() ? "1" : "0"))
    try TrayMenu_HardenHoleUiTransition("tray_open_search", 1200)
    catch {
    }
    try NormalizeCapsLockRuntimeForUiOpen()
    catch {
    }
    try TrayMenu_Log("prepare_search_from_hole_done")
}

TrayMenu_OpenSearchLockWatchdog(*) {
    global g_SCWV_TrayOpenLock, g_SCWV_TrayOpenLockTick
    if (g_SCWV_TrayOpenLock && g_SCWV_TrayOpenLockTick > 0 && (A_TickCount - g_SCWV_TrayOpenLockTick) >= 1500) {
        g_SCWV_TrayOpenLock := false
        g_SCWV_TrayOpenLockTick := 0
        try TrayMenu_Log("open_search_lock_watchdog_release")
    }
}

ShowSearchCenterFromMenu(*) {
    SetTimer((*) => ShowSearchCenterFromMenuRun(), -10)
}

ShowSearchCenterFromMenuRun(*) {
    Critical "Off"
    global TrayMenuGUI

    try TrayMenu_Log("show_search_from_menu_begin")
    try {
        if (SCWV_IsRevealedToUser() && !SearchCenter_IsOpeningOrBusy()) {
            TrayMenu_Log("show_search_from_menu_toggle_close")
            if (TrayMenuGUI != 0) {
                try {
                    TrayMenuGUI.Destroy()
                    TrayMenuGUI := 0
                    SetTimer(CheckTrayMenuMousePosition, 0)
                }
            }
            try SearchCenterUnifiedClose("tray_toggle_search", true, true)
            catch {
                try SearchCenterUnifiedClose("tray_toggle_search_fallback", false, true)
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
            ; opening/busy 时优先复用当前实例，避免强制关闭打断 WebView 初始化造成白屏。
            try SurfaceIntent_OpenSearch("", "search_hotkey")
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
    try {
        SurfaceIntent_Open("clipboard_panel")
        TrayMenu_Log("open_clipboard_from_menu_done")
    } catch as err {
        try TrayMenu_Log("open_clipboard_from_menu_failed msg=" . err.Message)
    }
}

TrayMenu_OpenScreenshotAction(*) {
    try TrayMenu_Log("open_screenshot_from_menu")
    ExecuteScreenshotWithMenu()
}

TrayMenu_OpenConfigAction(*) {
    try TrayMenu_Log("open_config_from_menu")
    ; Config open lock can remain stale after interrupted hole-mode transitions.
    ; For tray action, force-release lock first and retry with core open path fallback.
    try g_ConfigOpenInFlight := false
    try g_ConfigOpenInFlightSince := 0
    try g_ConfigWebViewOpenStartTick := 0
    try {
        ShowConfigGUI_Safe()
        TrayMenu_Log("open_config_from_menu_done")
    } catch as err {
        try TrayMenu_Log("open_config_from_menu_safe_failed msg=" . err.Message)
        try SetTimer((*) => ShowConfigGUI_Core(), -30)
    }
}

TrayMenu_SwitchToToolbarFromHoleMenu(*) {
    global AppearanceActivationMode
    try TrayMenu_Log("switch_to_toolbar_from_hole_menu begin")
    try {
        if FuncExists("FloatingToolbar_CancelReturnToHoleAfterNiuma")
            FloatingToolbar_CancelReturnToHoleAfterNiuma()
        Nmer_PersistAndApplyActivationMode("toolbar")
        try TrayMenu_Log("switch_to_toolbar_from_hole_menu done mode=" . NormalizeAppearanceActivationMode(AppearanceActivationMode))
    } catch as err {
        try TrayMenu_Log("switch_to_toolbar_failed msg=" . err.Message)
        try FloatingToolbar_SetActivationMode("toolbar")
        catch as err2 {
            try TrayMenu_Log("switch_to_toolbar_fallback_failed msg=" . err2.Message)
        }
    }
}

TrayMenu_AddStableCoreItems(MenuItems, mode, ftVis, bubVis) {
    global GDHO_VISIBLE, g_GDHO_CurrentPhase, GDHO_PHASE_OPEN, GDHO_PHASE_OPENING
    if (mode = "hole") {
        holeVisible := false
        try holeVisible := (g_GDHO_CurrentPhase = GDHO_PHASE_OPEN || g_GDHO_CurrentPhase = GDHO_PHASE_OPENING || GDHO_VISIBLE)
        catch {
            holeVisible := bubVis
        }
        if (holeVisible) {
            MenuItems.Push({ Text: "隐藏黑洞", Action: FloatingBubbleHideFromMenu, Icon: "☰" })
        } else {
            MenuItems.Push({ Text: "显示黑洞", Action: FloatingBubbleShowFromMenu, Icon: "☰" })
        }
        MenuItems.Push({ Text: "切换到悬浮栏", Action: TrayMenu_SwitchToToolbarFromHoleMenu, Icon: "▤" })
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
    MenuItems.Push({ Text: "彻底退出重启", Action: ((*) => TrayMenu_RunSceneCmd("tray_restart_clean")), Icon: "⟲" })
    MenuItems.Push({ Text: "[!] 强制重置搜索中心", Action: ((*) => TrayMenu_RunSceneCmd("tray_force_reinit_search")), Icon: "!" })
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
    global TrayMenuGUI, AppearanceActivationMode
    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    if (NormalizeAppearanceActivationMode(amRaw) = "hole") {
        try {
            if FuncExists("FloatingToolbar_CancelReturnToHoleAfterNiuma")
                FloatingToolbar_CancelReturnToHoleAfterNiuma()
            Nmer_PersistAndApplyActivationMode("toolbar")
        } catch {
        }
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

    try TrayMenu_Log("screenshot_direct_execute_begin")
    ExecuteScreenshotWithMenu()
    try TrayMenu_Log("screenshot_direct_execute_done")
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

    mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    if (mode = "hole") {
        TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenConfigAction, "config")
    } else
        TrayMenu_OpenConfigAction()
    try TrayMenu_Log("show_config_from_menu_end")
}

ExitFromMenu(*) {
    global TrayMenuGUI
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        } catch {
        }
    }
    try TrayMenu_Log("exit_from_menu begin")
    try TrayMenu_ForceBreakSearchCenterStuck("tray_exit_app")
    try CleanUp()
    ExitApp()
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
        SurfaceIntent_Close("floating_toolbar")
    }
}

Nmer_ScheduleCleanRestart() {
    ahkExe := A_AhkPath
    scriptPath := A_ScriptFullPath
    pid := DllCall("GetCurrentProcessId", "UInt")
    ; 等当前进程完全退出后再拉起，避免与 #SingleInstance Force 抢实例、WebView2 环境未释放
    ps := "while (Get-Process -Id " . pid . " -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 250 }; "
        . "Start-Process -FilePath '" . StrReplace(ahkExe, "'", "''") . "' -ArgumentList '" . StrReplace(scriptPath, "'", "''") . "'"
    try {
        Run('powershell.exe -NoProfile -WindowStyle Hidden -Command "' . ps . '"', , "Hide")
        try TrayMenu_Log("restart_clean_spawn_scheduled pid=" . pid)
        return
    } catch as err {
        try TrayMenu_Log("restart_clean_spawn_ps_failed msg=" . err.Message)
    }
    cmd := 'cmd /c ping 127.0.0.1 -n 4 >nul & start "" "' . ahkExe . '" "' . scriptPath . '"'
    try Run(cmd, , "Hide")
    catch {
    }
}

RestartAppCleanFromTrayMenu(*) {
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
    try TrayMenu_Log("restart_clean_begin")
    try FloatingToolbarSaveScale()
    catch {
    }
    try SaveFloatingToolbarPosition()
    catch {
    }
    try _Cfg_NormalizeIniEncoding(ConfigFile)
    catch {
    }
    try TrayMenu_ForceBreakSearchCenterStuck("tray_restart_clean")
    catch {
    }
    try {
        if FuncExists("SCWV_RequestHardClose")
            SCWV_RequestHardClose("tray_restart_clean_sync")
    } catch {
    }
    try {
        if FuncExists("HideFloatingToolbar")
            HideFloatingToolbar()
    } catch {
    }
    try GDHO_HideOverlay()
    catch {
    }
    try NiumaTtyd_StopProcess()
    catch {
    }
    try {
        if FuncExists("SearchCore_Shutdown")
            SearchCore_Shutdown("tray_restart_clean")
        else if ProcessExist("SearchCenterCore.exe")
            ProcessClose("SearchCenterCore.exe")
    } catch {
    }
    try {
        if FuncExists("WebView2_PrepareForScriptReload")
            WebView2_PrepareForScriptReload()
    } catch {
    }
    try {
        if FuncExists("Nmer_StopWailsBridge")
            Nmer_StopWailsBridge()
    } catch {
    }
    try NativeDropBridge_Stop()
    catch {
    }
    Nmer_ScheduleCleanRestart()
    try TrayMenu_Log("restart_clean_exit")
    ExitApp()
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
    try {
        if FuncExists("Nmer_WailsBridgePrepareForScriptReload")
            Nmer_WailsBridgePrepareForScriptReload()
    } catch {
    }
    try {
        if FuncExists("WebView2_PrepareForScriptReload")
            WebView2_PrepareForScriptReload()
    } catch {
    }
    ; 等当前进程退出后再拉起，避免与 #SingleInstance Force 抢实例导致 Run(AutoHotkey64) 失败（error -1）
    Nmer_ScheduleCleanRestart()
    try TrayMenu_Log("reload_clean_spawn_scheduled")
    ExitApp()
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

    NormalizeTrayIconValue(val) {
        v := Trim(String(val))
        if (v = "")
            return ""
        ; 防御脏数据：单个英文字母（如 h）通常不是有效图标，统一回退为圆点。
        if RegExMatch(v, "^[A-Za-z]$")
            return "•"
        return v
    }

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
            safeIcon := NormalizeTrayIconValue(Item.Icon)
            if (safeIcon != Item.Icon) {
                try TrayMenu_Log("icon_sanitized idx=" . Index . " text=" . (Item.HasProp("Text") ? String(Item.Text) : "") . " raw=" . String(Item.Icon) . " safe=" . safeIcon)
                catch {
                }
            }
            IconText := TrayMenuGUI.Add("Text", "x" . IconLeftMargin . " y" . ItemY . " w" . IconSize . " h" . MenuItemHeight . " Center 0x200 c" . iconColor . " BackgroundTrans vMenuItemIcon" . Index, safeIcon)
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
    global g_TraySvgRenderInFlight
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
            renderKey := svgPath "|" size "|" themeKey
            if !(g_TraySvgRenderInFlight.Has(renderKey) && g_TraySvgRenderInFlight[renderKey]) {
                g_TraySvgRenderInFlight[renderKey] := true
                TrayMenu_QueueSvgRasterize(svgPath, size, pngPath, renderKey)
            }
            return ""
        }
        return pngPath
    } catch {
        return ""
    }
}

TrayMenu_QueueSvgRasterize(svgPath, size, pngPath, renderKey) {
    SetTimer((*) => TrayMenu_RunSvgRasterize(svgPath, size, pngPath, renderKey), -10)
}

TrayMenu_RunSvgRasterize(svgPath, size, pngPath, renderKey, *) {
    global g_TraySvgRenderInFlight
    try {
        edge := ResolveHeadlessBrowserForSvg()
        if (edge = "") {
            g_TraySvgRenderInFlight[renderKey] := false
            return
        }
        url := "file:///" . StrReplace(svgPath, "\", "/")
        bgColor := (TrayPopup_GetThemeMode() = "light") ? "f7f7f7" : "1a1a1a"
        cmd := '"' . edge . '" --headless --disable-gpu --hide-scrollbars --default-background-color=' . bgColor . ' --window-size=' . size . ',' . size . ' --screenshot="' . pngPath . '" "' . url . '"'
        Run(cmd, , "Hide")
    } catch {
    }
    SetTimer((*) => TrayMenu_ClearSvgRenderFlag(renderKey), -4000)
}

TrayMenu_ClearSvgRenderFlag(renderKey, *) {
    global g_TraySvgRenderInFlight
    try g_TraySvgRenderInFlight[renderKey] := false
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

TrayMenu_ResetPopupState(reason := "") {
    global TrayMenuPopupBusy, TrayMenuPopupPending, TrayMenuPopupPendingLParam, TrayMenuPopupPendingStart, TrayMenuPopupBusySince
    TrayMenuPopupBusy := false
    TrayMenuPopupPending := false
    TrayMenuPopupPendingLParam := 0
    TrayMenuPopupPendingStart := 0
    TrayMenuPopupBusySince := 0
    try TrayMenu_Log("popup_state_reset reason=" . reason)
}

FloatingBubbleShowFromMenu(*) {
    FloatingBubbleShowFromMenuRun()
}

TrayMenu_DeferCloseSearchAfterHoleShow(*) {
    try SCWV_SubmitIntent("FORCE_CLOSE", 10, Map("reason", "tray_menu_show_hole"))
    catch {
    }
}

FloatingBubbleShowFromMenuRun(*) {
    global GDHO_HOST_W, GDHO_HOST_H, GDHO_POSITION_MODE, g_IsUIVisibleTransitioning
    global GDHO_SCREEN_X, GDHO_SCREEN_Y, GDHO_FIXED_X, GDHO_FIXED_Y
    global g_TrayMenuTransitionStartTick, g_TrayMenuSuppressOpenUntil
    try CloseDarkStylePopupMenu()
    try TrayMenu_ResetPopupState("tray_menu_show_hole_begin")
    g_TrayMenuSuppressOpenUntil := A_TickCount + 120
    g_IsUIVisibleTransitioning := false
    g_TrayMenuTransitionStartTick := 0
    try {
        try TrayMenu_Log("tray_menu_show_hole_begin")
        GDHO_POSITION_MODE := "fixed"
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        hostW := Integer(GDHO_HOST_W > 0 ? GDHO_HOST_W : 620)
        hostH := Integer(GDHO_HOST_H > 0 ? GDHO_HOST_H : 620)
        sx := Integer(mx - hostW + 36)
        sy := Integer(my - 56)
        try GDHO_SCREEN_X := sx
        try GDHO_SCREEN_Y := sy
        try GDHO_FIXED_X := sx
        try GDHO_FIXED_Y := sy
        if FuncExists("GDHO_PinToDesktop")
            GDHO_PinToDesktop("text")
        else
            GDHO_RequestOpen(Map("reason", "hole_mode_starry", "payload", "text", "positionMode", "fixed", "screenX", sx, "screenY", sy))
        try TrayMenu_Log("tray_menu_show_hole positioned screen_x=" . sx . " screen_y=" . sy)
        SetTimer(TrayMenu_DeferCloseSearchAfterHoleShow, -1)
    } catch as err {
        try TrayMenu_Log("tray_menu_show_hole_failed msg=" . err.Message)
    } finally {
        try TrayMenu_ResetPopupState("tray_menu_show_hole_end")
    }
}

FloatingBubbleHideFromMenu(*) {
    try GDHO_RequestClose("tray_hide_hole")
    catch {
    }
    try FloatingToolbar_SetActivationMode("tray")
    catch {
    }
}

TrayMenu_RunSceneCmd(cmdId) {
    SetTimer((*) => TrayMenu_RunSceneCmdRun(cmdId), -10)
}

TrayMenu_RunSceneCmdRun(cmdId) {
    Critical "Off"
    c := TrayMenu_NormalizeCmdId(cmdId)
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
        case "tray_restart_clean":
            try RestartAppCleanFromTrayMenu()
            return
        case "tray_force_reinit_search":
            try SCWV_ForceReinitFromTray()
            return
        case "tray_exit_app":
            try ExitFromMenu()
            return
        case "tray_show_hole_input_panel":
            try TrayMenu_ShowHoleInputPanel()
            return
        case "tray_hide_hole_input_panel":
            try TrayMenu_HideHoleInputPanel()
            return
        case "tray_toggle_hole_panel_passthrough":
            try TrayMenu_ToggleHolePanelPassthrough()
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

TrayMenu_NormalizeCmdId(cmdId) {
    c := StrLower(Trim(String(cmdId)))
    if (c = "")
        return ""
    c := StrReplace(c, "\", "/")
    if (SubStr(c, 1, 5) = "tray/")
        c := "tray_" . SubStr(c, 6)
    c := StrReplace(c, "tray:show_search", "tray_show_search")
    c := StrReplace(c, "tray:show_clipboard", "tray_show_clipboard")
    c := StrReplace(c, "tray:show_screenshot", "tray_show_screenshot")
    c := StrReplace(c, "tray:show_config", "tray_show_config")
    c := StrReplace(c, "tray:toggle_toolbar", "tray_toggle_toolbar")
    c := StrReplace(c, "tray:hide_toolbar", "tray_hide_toolbar")
    c := StrReplace(c, "tray:reload_script", "tray_reload_script")
    c := StrReplace(c, "tray:restart_clean", "tray_restart_clean")
    c := StrReplace(c, "tray:force_reinit_search", "tray_force_reinit_search")
    c := StrReplace(c, "tray:exit_app", "tray_exit_app")
    c := StrReplace(c, "tray:show_hole_input_panel", "tray_show_hole_input_panel")
    c := StrReplace(c, "tray:hide_hole_input_panel", "tray_hide_hole_input_panel")
    c := StrReplace(c, "tray:toggle_hole_panel_passthrough", "tray_toggle_hole_panel_passthrough")
    return c
}

TrayMenu_MakeSceneAction(cmdId) {
    _cid := String(cmdId)
    return ((*) => TrayMenu_RunSceneCmd(_cid))
}

TrayMenu_BuildItemsFromSceneMenu(sceneKey := "tray_menu") {
    return TrayMenu_GetSceneItemsFromSnapshot(sceneKey)
}

TrayMenu_BuildItemsFromSceneMenuLive(sceneKey := "tray_menu", allowLoad := false) {
    global g_Commands, AppearanceActivationMode, g_LastValidTrayMenu
    items := []
    if (allowLoad) {
        try {
            if IsSet(_LoadCommands)
                _LoadCommands()
        } catch {
        }
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
        cid := TrayMenu_NormalizeCmdId(cid0)
        if (cid = "" || seen.Has(cid))
            continue
        if (cid = "tray_show_hole_input_panel" || cid = "tray_hide_hole_input_panel" || cid = "tray_toggle_hole_panel_passthrough")
            continue
        seen[cid] := true
        if (IsObject(vm) && vm.Has(cid) && !vm[cid])
            continue
        nm := cid
        if (IsObject(cmdList) && cmdList.Has(cid) && cmdList[cid] is Map && cmdList[cid].Has("name") && cmdList[cid]["name"] != "")
            nm := String(cmdList[cid]["name"])
        if (nm = "" || nm = cid)
            nm := TrayMenu_GetSceneFallbackLabel(cid, nm)
        items.Push({ Text: nm, Action: TrayMenu_MakeSceneAction(cid), Icon: "•", CmdId: cid })
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
        case "tray_restart_clean":
            return "彻底退出重启"
        case "tray_force_reinit_search":
            return "[!] 强制重置搜索中心"
        case "tray_exit_app":
            return "退出工具"
        case "tray_show_hole_input_panel":
            return "显示输入面板"
        case "tray_hide_hole_input_panel":
            return "隐藏输入面板"
        case "tray_toggle_hole_panel_passthrough":
            return "切换输入面板穿透"
        default:
            return defaultLabel
    }
}

TrayMenu_ShowHoleInputPanel() {
    global g_TrayHoleInputPanelVisible
    g_TrayHoleInputPanelVisible := true
    try GDHO_RunJS("window.HoleOverlay?.setManualPanelVisible?.(true)")
    TrayMenu_MarkSceneDirty("show_hole_input_panel")
}

TrayMenu_HideHoleInputPanel() {
    global g_TrayHoleInputPanelVisible
    g_TrayHoleInputPanelVisible := false
    try GDHO_RunJS("window.HoleOverlay?.setManualPanelVisible?.(false)")
    TrayMenu_MarkSceneDirty("hide_hole_input_panel")
}

TrayMenu_ToggleHolePanelPassthrough() {
    global g_TrayHolePanelPassthrough
    g_TrayHolePanelPassthrough := !g_TrayHolePanelPassthrough
    TrayMenu_ApplyHolePanelPassthrough(g_TrayHolePanelPassthrough)
    TrayMenu_MarkSceneDirty("toggle_hole_panel_passthrough")
}

TrayMenu_ApplyHolePanelPassthrough(enable := false) {
    global g_TrayHolePanelPassthrough
    on := !!enable
    g_TrayHolePanelPassthrough := on
    try NativeDropDiag_Log("[TRAY_PANEL_PE] tray_apply passthrough=" . (on ? "1" : "0") . " (1=CSS pointer-events:none on manual panel)")
    if !on {
        if FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled() {
            if FuncExists("GDHO_ShowPanel")
                try GDHO_ShowPanel("tray_panel_solid")
            return
        }
        if FuncExists("GDHO_ApplyManualPanelInteractive") {
            try GDHO_ApplyManualPanelInteractive("tray_panel_solid")
            return
        }
    }
    js := "(function(){try{var on=" . (on ? "true" : "false") . ";var p=document.querySelector('#manual-config-panel')||document.querySelector('#manualPanel');var cb=document.getElementById('panelPassthrough');if(cb)cb.checked=on;if(p)p.style.pointerEvents=on?'none':'auto';if(cb){try{cb.dispatchEvent(new Event('change'));}catch(_e){}}}catch(_e){}})();"
    if FuncExists("GDHO_RunPanelJS") {
        try GDHO_RunPanelJS(js)
    } else if FuncExists("GDHO_RunJS") {
        try GDHO_RunJS(js)
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
    global GDHO_VISIBLE, NativeDropSessionActive, g_IsUIVisibleTransitioning, g_GDHO_CurrentPhase, g_GDHO_CurrentToken
    trayBuildStart := A_TickCount
    phaseStart := trayBuildStart
    ; Ensure stale popup instance is gone before creating a new one.
    try CloseDarkStylePopupMenu()

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
    try TrayMenu_Log("custom_popup_state mode=" . mode . " ft_vis=" . (ftVis ? "1" : "0") . " bub_vis=" . (bubVis ? "1" : "0") . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " search_visible=" . (searchVisible ? "1" : "0") . " gdho=" . (gdhoVisible ? "1" : "0") . " gdho_phase=" . (IsSet(g_GDHO_CurrentPhase) ? g_GDHO_CurrentPhase : "") . " gdho_token=" . (IsSet(g_GDHO_CurrentToken) ? g_GDHO_CurrentToken : 0) . " native=" . (nativeActive ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " create_inflight=" . (g_SCWV_CreateInFlight ? "1" : "0"))
    catch {
    }
    try TrayMenu_Log("tray_build_phase=state elapsed_ms=" . (A_TickCount - phaseStart))
    phaseStart := A_TickCount
    TrayMenu_AddStableCoreItems(MenuItems, mode, ftVis, bubVis)

    sceneItems := []
    sceneItems := TrayMenu_BuildItemsFromSceneMenu("tray_menu")
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
    try TrayMenu_Log("tray_build_phase=snapshot elapsed_ms=" . (A_TickCount - phaseStart))
    phaseStart := A_TickCount

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
    try TrayMenu_Log("tray_build_phase=render elapsed_ms=" . (A_TickCount - phaseStart))
    try TrayMenu_Log("custom_popup_build_done items=" . MenuItems.Length . " elapsed_ms=" . (A_TickCount - trayBuildStart))
    ShowDarkStylePopupMenuAt(MenuItems, posX, posY)
}

TrayMenu_StressIntentStorm() {
    ; 1s intent storm:
    ; open search -> simulate blur(close) -> open search -> blackhole handoff
    try TrayMenu_Log("storm_begin")
    try SCWV_SubmitIntent("OPEN", 20, Map("reason", "storm_open_1"))
    SetTimer((*) => SCWV_SubmitIntent("CLOSE", 25, Map("reason", "storm_blur_close")), -180)
    SetTimer((*) => SCWV_SubmitIntent("OPEN", 20, Map("reason", "storm_open_2")), -360)
    SetTimer((*) => TrayMenu_HardenHoleUiTransition("storm_handoff", 1200), -540)
    SetTimer((*) => TrayMenu_Log("storm_end"), -900)
}
