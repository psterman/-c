; SearchCenterWebLlm.ahk — 搜索中心「网页大模型」子 GUI WebView2 叠层
#Requires AutoHotkey v2.0
;@reference SearchCenterWebLlm.d.ahk

#Include FuncExists.ahk
#Include SearchCenterWebLlmSites.ahk

global g_SCWebLlm_ParentHwnd := 0
global g_SCWebLlm_Visible := false
global g_SCWebLlm_ContentGui := 0
global g_SCWebLlm_ContentHostHwnd := 0
global g_SCWebLlm_Ctrl := 0
global g_SCWebLlm_WV2 := 0
global g_SCWebLlm_Env := 0
global g_SCWebLlm_ActiveSiteId := ""
global g_SCWebLlm_Ready := false
global g_SCWebLlm_CreateInFlight := false
global g_SCWebLlm_LastBoundsKey := ""
global g_SCWebLlm_ContentRectReady := false
global g_SCWebLlm_ContentRect := Map("left", 0, "top", 220, "width", 800, "height", 500)
global g_SCWebLlm_TokenNavCompleted := 0
global g_SCWebLlm_StateCache := Map()
global g_SCWebLlm_PendingOpenRequest := 0
global g_SCWebLlm_SiteHosts := Map()
global g_SCWebLlm_MultiMobile := true
global g_SCWebLlm_EmbedBootstrapped := false
global g_SCWebLlm_OwnerOverlay := false
global g_SCWebLlm_EmbedRequested := false
global g_SCWebLlm_WatchdogToken := 0
global g_SCWebLlm_BootstrapScheduled := false
global g_SCWebLlm_BootstrapInFlight := false
global g_SCWebLlm_EmbedFocusGuardUntil := 0
global g_SCWebLlm_BootstrapWaitCount := 0
global g_SCWebLlm_MainWebViewLowered := false
global g_SCWebLlm_BoundsRetryScheduled := false
global g_SCWebLlm_ScrollX := 0
global g_SCWebLlm_ColumnWidths := Map()
global g_SCWebLlm_ResizeRails := Map()
global g_SCWebLlm_RailDrag := 0
global g_SCWebLlm_RailInputHooked := false
global g_SCWebLlm_ChildHostBoundsCache := Map()
global g_SCWebLlm_HostClipCache := Map()
global g_SCWebLlm_ScrollOnlyPass := false
global g_SCWebLlm_PendingContentRect := 0
global g_SCWebLlm_SiteBoundsSig := Map()
global g_SCWebLlm_RailLayoutPushDue := 0
global g_SCWebLlm_LastColFillCss := 0
global g_SCWebLlm_PendingKeywords := Map()
global g_SCWebLlm_EdgeRails := Map()
global g_SCWebLlm_FocusGlow := Map()
global g_SCWebLlm_FocusGlowSig := ""
global g_SCWebLlm_BroadcastSynced := false
global g_SCWebLlm_LayoutSiteIds := []
global g_SCWebLlm_UnifiedHostActive := false
global g_SCWebLlm_UnifiedMultiRectActive := false
global g_SCWebLlm_UnifiedColumnRects := Map()
global g_SCWebLlm_UnifiedEmbedViewport := Map()
global g_SCWebLlm_UnifiedLayoutPaused := false
global g_SCWebLlm_UnifiedLayoutLiveDrag := false
global g_SCWebLlm_UnifiedSuspendGen := 0
global g_SCWebLlm_UnifiedLayoutBootstrapScheduled := false
global g_SCWebLlm_UnifiedLayoutNudgeTick := 0
global g_SCWebLlm_UnifiedLayoutNudgeCount := 0
global g_SCWebLlm_ScrollInputHooked := false
global g_SCWebLlm_EmbedBackdropHwnd := 0
global g_SCWebLlm_LastRaisedHostHwnd := 0

ScWebLlm_IsUnifiedLayoutPaused() {
    global g_SCWebLlm_UnifiedLayoutPaused
    return !!g_SCWebLlm_UnifiedLayoutPaused && ScWebLlm_IsUnifiedWorkbenchHost()
}

ScWebLlm_ShouldSkipEmbedWinOps() {
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return true
    return false
}

ScWebLlm_IsUsableChildHwnd(hwnd) {
    h := Integer(hwnd)
    if (h <= 0)
        return false
    if FuncExists("WebView2_IsUsableHwnd")
        return WebView2_IsUsableHwnd(h)
    try return !!DllCall("IsWindow", "Ptr", h, "Int")
    catch {
        return false
    }
}

ScWebLlm_EnsureEmbedBackdrop(parentHwnd, embedLeft, embedTop, embedW, embedH) {
    global g_SCWebLlm_EmbedBackdropHwnd, g_SCWebLlm_OwnerOverlay
    ph := Integer(parentHwnd)
    if !ph || embedW <= 0 || embedH <= 0
        return
    if !g_SCWebLlm_EmbedBackdropHwnd {
        created := SearchCenterWebLlm_CreateChildHostGui(ph, "0b1220")
        if !(created is Map) || !created.Has("hwnd")
            return
        g_SCWebLlm_EmbedBackdropHwnd := created["hwnd"]
    }
    SearchCenterWebLlm_PositionChildHost(g_SCWebLlm_EmbedBackdropHwnd, embedLeft, embedTop, embedW, embedH, true, ph)
    if !g_SCWebLlm_OwnerOverlay {
        try DllCall("SetWindowPos", "Ptr", g_SCWebLlm_EmbedBackdropHwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

ScWebLlm_HideEmbedBackdrop() {
    global g_SCWebLlm_EmbedBackdropHwnd
    if g_SCWebLlm_EmbedBackdropHwnd {
        try SearchCenterWebLlm_PositionChildHost(g_SCWebLlm_EmbedBackdropHwnd, 0, 0, 0, 0, false)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

ScWebLlm_ApplyActiveSiteChrome(activeSiteId := "", parentHwnd := 0) {
    global g_SCWebLlm_Visible, g_SCWebLlm_LastColFillCss
    if !ScWebLlm_ShouldShowWebEmbed() || !g_SCWebLlm_Visible
        return false
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : ScWebLlm_ResolveEmbedHostHwnd()
    if !hwnd
        return false
    activeNorm := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (activeNorm = "")
        activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if !g_SCWebLlm_OwnerOverlay && !g_SCWebLlm_MainWebViewLowered
        SearchCenterWebLlm_LowerMainWebView()
    SearchCenterWebLlm_RaiseSiteHosts(activeNorm)
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    if ScWebLlm_ResolveClientRect(hwnd, &embedLeft, &embedTop, &embedW, &embedH) {
        embedW := ScWebLlm_ExpandEmbedWidthToParent(hwnd, embedLeft, embedW)
        embedH := ScWebLlm_FullEmbedColumnHeight(hwnd, embedTop, Max(140, Integer(embedH)))
        ScWebLlm_EnsureEmbedBackdrop(hwnd, embedLeft, embedTop, embedW, embedH)
        fillCss := Integer(g_SCWebLlm_LastColFillCss)
        SearchCenterWebLlm_ApplyFocusGlow(siteIds, activeNorm, embedLeft, embedTop, embedW, embedH, hwnd, fillCss)
    }
    SearchCenterWebLlm_RaiseResizeRailsAboveHosts()
    ScWebLlm_RaiseFocusGlowTop()
    return true
}

ScWebLlm_MinColumnWidth() {
    return 280
}

ScWebLlm_AbsMinColumnWidth() {
    return 200
}

ScWebLlm_ColumnGap() {
    return 8
}

ScWebLlm_ColumnGapDragCss() {
    return 14
}

ScWebLlm_IdleRailHitCss() {
    return ScWebLlm_ColumnGap()
}

ScWebLlm_FocusRailLineCss() {
    return 6
}

ScWebLlm_ClampColumnToEmbed(&colLeft, &colW, embedLeft, embedW) {
    embedRight := embedLeft + embedW
    if (colLeft + colW > embedRight)
        colW := Max(0, embedRight - colLeft)
    return (colW > 0)
}

ScWebLlm_ColumnIntersectsViewport(colLeft, colW, embedLeft, embedW) {
    if (colW <= 0 || embedW <= 0)
        return false
    embedRight := embedLeft + embedW
    return (colLeft < embedRight && (colLeft + colW) > embedLeft)
}

; 计算列与 embed 视口的可见段（用于卷帘裁剪 / glow / rail）
ScWebLlm_ComputeColumnVisibleSegment(colL, colW, embedLeft, embedW, &visL, &visW) {
    visL := 0
    visW := 0
    if (colW <= 0 || embedW <= 0)
        return false
    embedRight := embedLeft + embedW
    colRight := colL + colW
    if (colRight <= embedLeft || colL >= embedRight)
        return false
    visL := Max(colL, embedLeft)
    visRight := Min(colRight, embedRight)
    visW := visRight - visL
    return (visW > 8)
}

ScWebLlm_ClearHostViewportClip(hostHwnd) {
    global g_SCWebLlm_HostClipCache
    if !hostHwnd || ScWebLlm_ShouldSkipEmbedWinOps() || !ScWebLlm_IsUsableChildHwnd(hostHwnd)
        return
    if g_SCWebLlm_HostClipCache.Has(hostHwnd)
        g_SCWebLlm_HostClipCache.Delete(hostHwnd)
    try DllCall("user32\SetWindowRgn", "Ptr", hostHwnd, "Ptr", 0, "Int", 1)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

; 卷帘：HWND 保持全列宽，超出 embed 左右边界的部分用 SetWindowRgn 裁掉
ScWebLlm_ApplyHostViewportClip(hostHwnd, colL, colW, colH, embedLeft, embedW) {
    global g_SCWebLlm_HostClipCache
    if !hostHwnd || colW <= 0 || colH <= 0 || ScWebLlm_ShouldSkipEmbedWinOps() || !ScWebLlm_IsUsableChildHwnd(hostHwnd)
        return false
    embedRight := embedLeft + embedW
    colRight := colL + colW
    if (colRight <= embedLeft || colL >= embedRight) {
        clipKey := "out"
        if g_SCWebLlm_HostClipCache.Has(hostHwnd) && (g_SCWebLlm_HostClipCache[hostHwnd] = clipKey)
            return false
        g_SCWebLlm_HostClipCache[hostHwnd] := clipKey
        try DllCall("user32\SetWindowRgn", "Ptr", hostHwnd, "Ptr", 0, "Int", 1)
        catch as e {
            ScWebLlm_Catch(e)
        }
        return false
    }
    if (colL >= embedLeft && colRight <= embedRight) {
        clipKey := "in"
        if g_SCWebLlm_HostClipCache.Has(hostHwnd) && (g_SCWebLlm_HostClipCache[hostHwnd] = clipKey)
            return true
        prevClip := g_SCWebLlm_HostClipCache.Has(hostHwnd) ? g_SCWebLlm_HostClipCache[hostHwnd] : ""
        g_SCWebLlm_HostClipCache[hostHwnd] := clipKey
        if (prevClip != "" && prevClip != "in") {
            try DllCall("user32\SetWindowRgn", "Ptr", hostHwnd, "Ptr", 0, "Int", 1)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        return true
    }
    visL := Max(colL, embedLeft)
    visR := Min(colRight, embedRight)
    rgnL := visL - colL
    rgnR := visR - colL
    clipKey := "c" . rgnL . "x" . rgnR . "x" . embedW
    if g_SCWebLlm_HostClipCache.Has(hostHwnd) && (g_SCWebLlm_HostClipCache[hostHwnd] = clipKey)
        return true
    g_SCWebLlm_HostClipCache[hostHwnd] := clipKey
    try {
        rgn := DllCall("gdi32\CreateRectRgn", "Int", rgnL, "Int", 0, "Int", rgnR, "Int", colH, "Ptr")
        if rgn {
            DllCall("user32\SetWindowRgn", "Ptr", hostHwnd, "Ptr", rgn, "Int", 1)
            return true
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
    return false
}

ScWebLlm_ExpandEmbedWidthToParent(hwnd, embedLeft, embedW) {
    global g_SCWebLlm_ContentRect
    w := Max(200, Integer(embedW))
    ; 仅信任 HTML 上报的 contentRect，勿撑满父窗（侧栏布局下会列错位/天窗）
    if (g_SCWebLlm_ContentRect is Map) {
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        if (cssW >= 160) {
            capW := ScWebLlm_CssToPhysical(cssW)
            if (capW >= 200)
                w := capW
        }
    }
    return w
}

ScWebLlm_ComputeStripFillExtraCss(siteIds, viewportWCss) {
    if !siteIds.Length || viewportWCss <= 0 || ScWebLlm_IsRailDragging()
        return 0
    ; 多列卷帘模式：末列保持固定宽，不自动拉伸填满视口
    if (siteIds.Length > 1)
        return 0
    minStrip := 0
    for sid in siteIds
        minStrip += ScWebLlm_MobileColumnCssWidth()
    if (siteIds.Length > 1)
        minStrip += (siteIds.Length - 1) * ScWebLlm_ColumnGap()
    if (minStrip > viewportWCss + 1)
        return 0
    strip := ScWebLlm_ComputeVirtualStripWidth(siteIds, viewportWCss)
    if (strip >= viewportWCss - 1)
        return 0
    return Max(0, viewportWCss - strip)
}

ScWebLlm_ComputeMinStripWidthCss(siteIds) {
    return ScWebLlm_ComputeVirtualStripWidth(siteIds, 0)
}

ScWebLlm_ResolveEmbedViewportCss(fallbackPhysW := 0) {
    global g_SCWebLlm_ContentRect
    if (g_SCWebLlm_ContentRect is Map) {
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        if (cssW >= 160)
            return cssW
    }
    if (fallbackPhysW > 0)
        return ScWebLlm_PhysicalToCss(fallbackPhysW)
    return 0
}

ScWebLlm_ComputeMaxScrollCss(siteIds, embedWCss) {
    if !siteIds.Length || embedWCss <= 0
        return 0
    return Max(0, ScWebLlm_ComputeMinStripWidthCss(siteIds) - embedWCss)
}

ScWebLlm_EmbedNeedsHorizontalScroll(siteIds, embedWCss) {
    if !siteIds.Length || embedWCss <= 0
        return false
    minStrip := 0
    for sid in siteIds
        minStrip += ScWebLlm_MobileColumnCssWidth()
    if (siteIds.Length > 1)
        minStrip += (siteIds.Length - 1) * ScWebLlm_ColumnGap()
    if (minStrip > embedWCss + 1)
        return true
    return ScWebLlm_ComputeMinStripWidthCss(siteIds) > embedWCss + 1
}

ScWebLlm_ClampScrollForFill(siteIds, embedWCss) {
    global g_SCWebLlm_ScrollX
    if !siteIds.Length || embedWCss <= 0
        return false
    changed := false
    if ScWebLlm_EmbedNeedsHorizontalScroll(siteIds, embedWCss) {
        maxScroll := ScWebLlm_ComputeMaxScrollCss(siteIds, embedWCss)
        if (g_SCWebLlm_ScrollX > maxScroll) {
            g_SCWebLlm_ScrollX := maxScroll
            changed := true
        }
        return changed
    }
    strip := ScWebLlm_ComputeVirtualStripWidth(siteIds, embedWCss)
    fill := ScWebLlm_ComputeStripFillExtraCss(siteIds, embedWCss)
    if (strip <= embedWCss + 1 && g_SCWebLlm_ScrollX > 0) {
        g_SCWebLlm_ScrollX := 0
        changed := true
    }
    if (fill > 0 && strip + fill <= embedWCss + 1 && g_SCWebLlm_ScrollX > 0) {
        g_SCWebLlm_ScrollX := 0
        changed := true
    }
    maxScroll := Max(0, strip + fill - embedWCss)
    if (g_SCWebLlm_ScrollX > maxScroll) {
        g_SCWebLlm_ScrollX := maxScroll
        changed := true
    }
    return changed
}

ScWebLlm_EnsureActiveColumnInView(siteIds, activeSiteId, embedWCss) {
    global g_SCWebLlm_ScrollX, g_SCWebLlm_LastColFillCss
    if !siteIds.Length || embedWCss <= 0
        return false
    activeNorm := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (activeNorm = "")
        return false
    activeIdx := 0
    for i, sid in siteIds {
        if (ScWebLlm_NormalizeSiteId(sid) = activeNorm) {
            activeIdx := i
            break
        }
    }
    if (activeIdx < 1)
        return false
    colLeftCss := 0
    if (activeIdx > 1) {
        Loop activeIdx - 1 {
            colLeftCss += ScWebLlm_ResolveColumnWidth(siteIds[A_Index], siteIds, embedWCss) + ScWebLlm_ColumnGap()
        }
    }
    colWCss := ScWebLlm_ResolveColumnWidth(siteIds[activeIdx], siteIds, embedWCss)
    if (activeIdx = siteIds.Length && g_SCWebLlm_LastColFillCss > 0)
        colWCss += Integer(g_SCWebLlm_LastColFillCss)
    strip := ScWebLlm_ComputeVirtualStripWidth(siteIds, embedWCss)
    fill := ScWebLlm_ComputeStripFillExtraCss(siteIds, embedWCss)
    needsScroll := ScWebLlm_EmbedNeedsHorizontalScroll(siteIds, embedWCss)
    maxScroll := needsScroll
        ? Max(0, ScWebLlm_ComputeMinStripWidthCss(siteIds) - embedWCss)
        : Max(0, strip + fill - embedWCss)
    desired := g_SCWebLlm_ScrollX
    if !needsScroll && (strip + fill <= embedWCss + 1) {
        desired := 0
    } else if (colLeftCss < g_SCWebLlm_ScrollX) {
        desired := colLeftCss
    } else if (colLeftCss + colWCss > g_SCWebLlm_ScrollX + embedWCss) {
        desired := Min(maxScroll, Max(0, colLeftCss + colWCss - embedWCss))
    }
    if (desired != g_SCWebLlm_ScrollX) {
        g_SCWebLlm_ScrollX := desired
        return true
    }
    return false
}

ScWebLlm_IsRailDragging() {
    global g_SCWebLlm_RailDrag
    return (g_SCWebLlm_RailDrag is Map)
}

ScWebLlm_FullEmbedColumnHeight(parentHwnd, embedTop, embedH) {
    global g_SCWebLlm_ContentRect
    h := Max(140, Integer(embedH))
    if (g_SCWebLlm_ContentRect is Map) {
        cssH := Integer(g_SCWebLlm_ContentRect.Get("height", 0))
        if (cssH >= 140) {
            capH := ScWebLlm_CssToPhysical(cssH)
            if (capH >= 140)
                h := capH
        }
    }
    return h
}

ScWebLlm_RaiseResizeRailTop(hostHwnd) {
    if !hostHwnd
        return
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_DefaultColumnWidth(embedW := 0, siteCount := 1) {
    ; 与 HTML 端默认列宽、移动版视口一致
    return Max(ScWebLlm_MinColumnWidth(), ScWebLlm_MobileColumnCssWidth())
}

ScWebLlm_GetStoredColumnWidth(siteId) {
    global g_SCWebLlm_ColumnWidths
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return ScWebLlm_DefaultColumnWidth(0, 1)
    if (g_SCWebLlm_ColumnWidths is Map && g_SCWebLlm_ColumnWidths.Has(sid)) {
        w := Integer(g_SCWebLlm_ColumnWidths[sid])
        if (w >= ScWebLlm_AbsMinColumnWidth())
            return w
    }
    return ScWebLlm_DefaultColumnWidth(0, 1)
}

ScWebLlm_ComputeVirtualStripWidthFromStored(siteIds) {
    total := 0
    n := siteIds.Length
    idx := 0
    for sid in siteIds {
        total += ScWebLlm_GetStoredColumnWidth(sid)
        idx += 1
        if (idx < n)
            total += ScWebLlm_ColumnGap()
    }
    return total
}

ScWebLlm_ResolveColumnWidth(siteId, siteIds, embedW := 0) {
    return ScWebLlm_GetStoredColumnWidth(siteId)
}

ScWebLlm_ComputeVirtualStripWidth(siteIds, embedW := 0) {
    total := 0
    n := siteIds.Length
    idx := 0
    for sid in siteIds {
        total += ScWebLlm_ResolveColumnWidth(sid, siteIds, embedW)
        idx += 1
        if (idx < n)
            total += ScWebLlm_ColumnGap()
    }
    return total
}

ScWebLlm_ComputeOthersStripWidth(siteIds, embedW := 0) {
    n := siteIds.Length
    if (n < 2)
        return 0
    others := []
    Loop n - 1
        others.Push(siteIds[A_Index])
    return ScWebLlm_ComputeVirtualStripWidth(others, embedW)
}

ScWebLlm_LazyLoadEnabled() {
    global g_SCWebLlm_MultiMobile
    return !!g_SCWebLlm_MultiMobile
}

ScWebLlm_LazyPrefetchColumns() {
    return 2
}

SearchCenterWebLlm_ListSitesToLoad(parentHwnd := 0) {
    global g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_LayoutSiteIds
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive {
        out := []
        for sid in g_SCWebLlm_LayoutSiteIds {
            sidNorm := ScWebLlm_NormalizeSiteId(sid)
            if (sidNorm != "" && g_SCWebLlm_UnifiedColumnRects.Has(sidNorm))
                out.Push(sidNorm)
        }
        if out.Length
            return out
    }
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    if !ScWebLlm_LazyLoadEnabled() || !siteIds.Length
        return siteIds
    hwnd := Integer(parentHwnd)
    if !hwnd
        hwnd := ScWebLlm_GetEmbedParentHwnd()
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    if !hwnd || !ScWebLlm_ResolveClientRect(hwnd, &embedLeft, &embedTop, &embedW, &embedH)
        return siteIds
    embedWCss := ScWebLlm_PhysicalToCss(embedW)
    fill := ScWebLlm_ComputeStripFillExtraCss(siteIds, embedWCss)
    strip := ScWebLlm_ComputeVirtualStripWidth(siteIds, embedWCss)
    ; 列总宽能放进视口时全部加载，避免右侧列白屏
    if (strip + fill <= embedWCss + 1)
        return siteIds
    prefetchCols := Max(1, ScWebLlm_LazyPrefetchColumns())
    prefetchPx := ScWebLlm_CssToPhysical((ScWebLlm_MobileColumnCssWidth() + ScWebLlm_ColumnGap()) * prefetchCols)
    viewL := embedLeft - prefetchPx
    viewR := embedLeft + embedW + prefetchPx
    out := []
    idx := 0
    for sid in siteIds {
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        if ScWebLlm_ComputeSiteColumnLayout(siteIds, "", embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, idx, fill) {
            if (colL + colW > viewL && colL < viewR)
                out.Push(sid)
        }
        idx += 1
    }
    if !out.Length
        out.Push(siteIds[1])
    global g_SCWebLlm_ActiveSiteId
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (activeNorm = "")
        activeNorm := ScWebLlm_DefaultSiteId()
    if (activeNorm != "") {
        found := false
        for s in out {
            if (ScWebLlm_NormalizeSiteId(s) = activeNorm) {
                found := true
                break
            }
        }
        if !found
            out.Push(activeNorm)
    }
    return out
}

ScWebLlm_SiteShouldLazyLoad(sid, parentHwnd := 0) {
    sidNorm := ScWebLlm_NormalizeSiteId(sid)
    if (sidNorm = "")
        return false
    for s in SearchCenterWebLlm_ListSitesToLoad(parentHwnd) {
        if (ScWebLlm_NormalizeSiteId(s) = sidNorm)
            return true
    }
    return false
}

ScWebLlm_SitesToLoadReady(parentHwnd := 0) {
    for sid in SearchCenterWebLlm_ListSitesToLoad(parentHwnd) {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            return false
        if rec.Get("createInFlight", false)
            return false
        if !rec.Get("ready", false) || !IsObject(rec.Get("wv2", 0))
            return false
    }
    return true
}

SearchCenterWebLlm_SetColumnLayout(layout) {
    global g_SCWebLlm_ScrollX, g_SCWebLlm_ColumnWidths, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRect
    if !(layout is Map)
        return false
    scrollChanged := false
    if layout.Has("scrollX") {
        nx := Max(0, Integer(layout["scrollX"]))
        if layout.Has("stripWidth") && layout.Has("viewportWidth") {
            maxS := Max(0, Integer(layout["stripWidth"]) - Integer(layout["viewportWidth"]))
            if (nx > maxS)
                nx := maxS
        }
        if (nx != g_SCWebLlm_ScrollX) {
            g_SCWebLlm_ScrollX := nx
            scrollChanged := true
        }
    }
    if layout.Has("viewportWidth") {
        vpW := Integer(layout["viewportWidth"])
        if (vpW >= 160) {
            global g_SCWebLlm_ContentRect
            if !(g_SCWebLlm_ContentRect is Map)
                g_SCWebLlm_ContentRect := Map()
            prevW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
            if (Abs(vpW - prevW) > 6) {
                g_SCWebLlm_ContentRect["width"] := vpW
                g_SCWebLlm_LastBoundsKey := ""
                scrollChanged := true
            }
        }
    }
    colsChanged := false
    fillExtra := layout.Has("fillExtra") ? Max(0, Integer(layout["fillExtra"])) : 0
    orderedIds := []
    if layout.Has("columns") {
        cols := layout["columns"]
        if (cols is Array) {
            for col in cols {
                if !(col is Map)
                    continue
                sid := ScWebLlm_NormalizeSiteId(col.Get("id", ""))
                if (sid != "")
                    orderedIds.Push(sid)
            }
        }
    }
    broadcastChanged := false
    if orderedIds.Length {
        normalized := ScWebLlm_NormalizeBroadcastSiteIds(orderedIds)
        prevIds := SearchCenterWebLlm_ListLayoutSiteIds()
        if (normalized.Length != prevIds.Length)
            broadcastChanged := true
        else {
            for i, sid in normalized {
                if (i > prevIds.Length || ScWebLlm_NormalizeSiteId(prevIds[i]) != sid) {
                    broadcastChanged := true
                    break
                }
            }
        }
        if broadcastChanged
            ScWebLlm_SyncBroadcastLayoutFromColumnIds(orderedIds)
    }
    layoutSites := SearchCenterWebLlm_ListLayoutSiteIds()
    lastSid := layoutSites.Length ? layoutSites[layoutSites.Length] : ""
    if layout.Has("columns") {
        cols := layout["columns"]
        if (cols is Array) {
            next := Map()
            for col in cols {
                if !(col is Map)
                    continue
                sid := ScWebLlm_NormalizeSiteId(col.Get("id", ""))
                w := Integer(col.Get("width", 0))
                if (sid != "" && w >= ScWebLlm_AbsMinColumnWidth())
                    next[sid] := w
            }
            if (fillExtra > 0 && lastSid != "" && next.Has(lastSid)) {
                w := Integer(next[lastSid])
                if (w > fillExtra + ScWebLlm_MinColumnWidth() - 1)
                    next[lastSid] := w - fillExtra
            }
            if (next.Count != g_SCWebLlm_ColumnWidths.Count)
                colsChanged := true
            if !colsChanged {
                for sid, w in next {
                    if !g_SCWebLlm_ColumnWidths.Has(sid) || Integer(g_SCWebLlm_ColumnWidths[sid]) != w {
                        colsChanged := true
                        break
                    }
                }
            }
            g_SCWebLlm_ColumnWidths := next
        }
    }
    embedWCss := 0
    if (g_SCWebLlm_ContentRect is Map) {
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        if (cssW > 0)
            embedWCss := cssW
    }
    if (embedWCss <= 0)
        embedWCss := ScWebLlm_ResolveEmbedViewportCss(0)
    if (embedWCss > 0 && ScWebLlm_ClampScrollForFill(layoutSites, embedWCss)) {
        scrollChanged := true
        g_SCWebLlm_LastBoundsKey := ""
    }
    forceBounds := layout.Has("scrollX") || scrollChanged || colsChanged || broadcastChanged
    if !forceBounds
        return true
    SearchCenterWebLlm_InvalidateLayoutCaches(false)
    if (colsChanged || scrollChanged || broadcastChanged) {
        try SearchCenterWebLlm_EnsureMissingSites(false)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    try SearchCenterWebLlm_ApplyBounds()
    catch as e {
        ScWebLlm_Catch(e)
    }
    return true
}

ScWebLlm_InstallResizeRailInputHook() {
    global g_SCWebLlm_RailInputHooked
    if g_SCWebLlm_RailInputHooked
        return
    OnMessage(0x201, ScWebLlm_OnResizeRailLButtonDown)
    g_SCWebLlm_RailInputHooked := true
    ScWebLlm_InstallEmbedScrollInputHook()
}

ScWebLlm_InstallEmbedScrollInputHook() {
    global g_SCWebLlm_ScrollInputHooked
    if g_SCWebLlm_ScrollInputHooked
        return
    OnMessage(0x020A, ScWebLlm_OnEmbedMouseWheel)
    OnMessage(0x020E, ScWebLlm_OnEmbedMouseHWheel)
    g_SCWebLlm_ScrollInputHooked := true
}

ScWebLlm_GetEmbedScreenRect(&screenL, &screenT, &screenW, &screenH) {
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        return false
    cl := 0, ct := 0, cw := 0, ch := 0
    if !ScWebLlm_ResolveClientRect(h, &cl, &ct, &cw, &ch)
        return false
    pt := Buffer(8, 0)
    NumPut("int", cl, pt, 0)
    NumPut("int", ct, pt, 4)
    if !DllCall("ClientToScreen", "Ptr", h, "Ptr", pt)
        return false
    screenL := NumGet(pt, 0, "int")
    screenT := NumGet(pt, 4, "int")
    screenW := cw
    screenH := ch
    return (screenW > 0 && screenH > 0)
}

ScWebLlm_ShouldHandleEmbedWheel(screenX, screenY) {
    global g_SCWebLlm_Visible
    if !g_SCWebLlm_Visible || !ScWebLlm_ShouldShowWebEmbed()
        return false
    sl := 0, st := 0, sw := 0, sh := 0
    if ScWebLlm_GetEmbedScreenRect(&sl, &st, &sw, &sh) {
        if (screenX >= sl && screenX < sl + sw && screenY >= st && screenY < st + sh)
            return true
    }
    pt := Buffer(8, 0)
    NumPut("int", screenX, pt, 0)
    NumPut("int", screenY, pt, 4)
    hw := 0
    try hw := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
    catch {
        return false
    }
    if hw && FuncExists("SearchCenterWebLlm_IsEmbedChildHwnd") {
        try {
            if SearchCenterWebLlm_IsEmbedChildHwnd(hw)
                return true
        } catch {
        }
    }
    return false
}

ScWebLlm_ScrollEmbedByCssDelta(cssDelta) {
    global g_SCWebLlm_ScrollX, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRect
    delta := Integer(cssDelta)
    if (delta = 0)
        return false
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    embedWCss := 0
    if (g_SCWebLlm_ContentRect is Map)
        embedWCss := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
    if !siteIds.Length || embedWCss <= 0 || !ScWebLlm_EmbedNeedsHorizontalScroll(siteIds, embedWCss)
        return false
    maxScroll := Max(0, ScWebLlm_ComputeMinStripWidthCss(siteIds) - embedWCss)
    nx := Max(0, Min(maxScroll, g_SCWebLlm_ScrollX + delta))
    if (nx = g_SCWebLlm_ScrollX)
        return false
    g_SCWebLlm_ScrollX := nx
    g_SCWebLlm_LastBoundsKey := ""
    try SearchCenterWebLlm_ApplyBounds()
    catch as e {
        ScWebLlm_Catch(e)
    }
    ScWebLlm_PushColumnLayoutToWeb(false, false)
    return true
}

ScWebLlm_ScrollEmbedByColumns(columnSteps) {
    steps := Integer(columnSteps)
    if (steps = 0)
        return false
    stepCss := ScWebLlm_MobileColumnCssWidth() + ScWebLlm_ColumnGap()
    return ScWebLlm_ScrollEmbedByCssDelta(steps * stepCss)
}

ScWebLlm_FocusAdjacentEmbedSite(step) {
    global g_SCWebLlm_ActiveSiteId
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    if (siteIds.Length < 2)
        return false
    cur := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    idx := 0
    for i, sid in siteIds {
        if (ScWebLlm_NormalizeSiteId(sid) = cur) {
            idx := i
            break
        }
    }
    if (idx < 1)
        idx := 1
    n := siteIds.Length
    nextIdx := idx + Integer(step)
    while (nextIdx < 1)
        nextIdx += n
    while (nextIdx > n)
        nextIdx -= n
    return ScWebLlm_ScrollEmbedToSite(siteIds[nextIdx])
}

ScWebLlm_InvalidateScrollClipCaches() {
    global g_SCWebLlm_HostClipCache
    g_SCWebLlm_HostClipCache := Map()
}

ScWebLlm_ApplyEmbedScrollCss(scrollX, viewportCss := 0, stripCss := 0, finalize := false) {
    global g_SCWebLlm_ScrollX, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWebLlm_ScrollOnlyPass
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    embedWCss := ScWebLlm_ResolveEmbedViewportCss(0)
    if (embedWCss <= 0 && viewportCss >= 160)
        embedWCss := viewportCss
    if (embedWCss <= 0)
        return false
    strip := stripCss > 0 ? stripCss : ScWebLlm_ComputeMinStripWidthCss(siteIds)
    maxScroll := Max(0, strip - embedWCss)
    nx := Max(0, Min(maxScroll, Integer(scrollX)))
    scrollChanged := (nx != g_SCWebLlm_ScrollX)
    if scrollChanged {
        g_SCWebLlm_ScrollX := nx
        g_SCWebLlm_LastBoundsKey := ""
        ScWebLlm_InvalidateScrollClipCaches()
    }
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if h {
        g_SCWebLlm_ParentHwnd := h
        g_SCWebLlm_Visible := true
    }
    if finalize {
        g_SCWebLlm_ScrollOnlyPass := false
        try SearchCenterWebLlm_ApplyBounds(h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    } else {
        g_SCWebLlm_ScrollOnlyPass := true
        try SearchCenterWebLlm_ApplyBounds(h)
        catch as e {
            ScWebLlm_Catch(e)
        }
        g_SCWebLlm_ScrollOnlyPass := false
    }
    if h {
        try SearchCenterWebLlm_EnsureMissingSites(false, h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return true
}

ScWebLlm_ScrollEmbedToSite(siteId) {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRect, g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "" || !ScWebLlm_IsSiteEnabled(sid))
        return false
    try ScWebLlm_EnsureSiteInBroadcastLayout(sid)
    catch as e {
        ScWebLlm_Catch(e)
    }
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    embedWCss := 0
    if (g_SCWebLlm_ContentRect is Map)
        embedWCss := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if h {
        g_SCWebLlm_ParentHwnd := h
        g_SCWebLlm_Visible := true
    }
    g_SCWebLlm_ActiveSiteId := sid
    try SearchCenterWebLlm_OpenSite(sid, false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    scrollChanged := false
    if (embedWCss > 0)
        scrollChanged := ScWebLlm_EnsureActiveColumnInView(siteIds, sid, embedWCss)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    siteReady := (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
    if (scrollChanged || !siteReady) {
        g_SCWebLlm_LastBoundsKey := ""
        try SearchCenterWebLlm_ApplyBounds(h)
        catch as e {
            ScWebLlm_Catch(e)
        }
        if scrollChanged
            ScWebLlm_PushColumnLayoutToWeb(false, false)
    } else {
        try ScWebLlm_ApplyActiveSiteChrome(sid, h)
        catch as e {
            ScWebLlm_Catch(e)
        }
        try SearchCenterWebLlm_EnsureMissingSites(false, h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    SearchCenterWebLlm_PulseFocusSite(sid)
    SearchCenterWebLlm_PushChromeState()
    return true
}

ScWebLlm_OnEmbedMouseWheel(wParam, lParam, msg, hwnd) {
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 0x7FFF)
        delta -= 0x10000
    if (delta = 0)
        return
    screenX := lParam & 0xFFFF
    screenY := (lParam >> 16) & 0xFFFF
    if (screenX > 0x7FFF)
        screenX -= 0x10000
    if (screenY > 0x7FFF)
        screenY -= 0x10000
    if !ScWebLlm_ShouldHandleEmbedWheel(screenX, screenY)
        return
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    embedWCss := 0
    global g_SCWebLlm_ContentRect
    if (g_SCWebLlm_ContentRect is Map)
        embedWCss := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
    if (siteIds.Length < 2)
        return
    if !ScWebLlm_EmbedNeedsHorizontalScroll(siteIds, embedWCss) && siteIds.Length <= 5
        return
    steps := (delta > 0) ? -1 : 1
    if ScWebLlm_FocusAdjacentEmbedSite(steps)
        return 1
}

ScWebLlm_OnEmbedMouseHWheel(wParam, lParam, msg, hwnd) {
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 0x7FFF)
        delta -= 0x10000
    if (delta = 0)
        return
    screenX := lParam & 0xFFFF
    screenY := (lParam >> 16) & 0xFFFF
    if (screenX > 0x7FFF)
        screenX -= 0x10000
    if (screenY > 0x7FFF)
        screenY -= 0x10000
    if !ScWebLlm_ShouldHandleEmbedWheel(screenX, screenY)
        return
    cssDelta := -Round(Float(delta) / 120.0 * (ScWebLlm_MobileColumnCssWidth() + ScWebLlm_ColumnGap()) * 0.45)
    if ScWebLlm_ScrollEmbedByCssDelta(cssDelta)
        return 1
}

ScWebLlm_IsResizeRailHwnd(hwnd) {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_EdgeRails
    target := Integer(hwnd)
    if !target
        return 0
    for , rec in g_SCWebLlm_ResizeRails {
        if !(rec is Map) || !rec.Has("hwnd")
            continue
        railHwnd := Integer(rec["hwnd"])
        if (railHwnd = target)
            return rec
        try {
            if (DllCall("GetAncestor", "Ptr", target, "UInt", 2, "Ptr") = railHwnd)
                return rec
        } catch {
        }
    }
    if (g_SCWebLlm_EdgeRails is Map) {
        for , rec in g_SCWebLlm_EdgeRails {
            if !(rec is Map) || !rec.Has("hwnd") || !rec.Get("draggable", false)
                continue
            railHwnd := Integer(rec["hwnd"])
            if (railHwnd = target)
                return rec
            try {
                if (DllCall("GetAncestor", "Ptr", target, "UInt", 2, "Ptr") = railHwnd)
                    return rec
            } catch {
            }
        }
    }
    return 0
}

ScWebLlm_OnResizeRailLButtonDown(wParam, lParam, msg, hwnd) {
    global g_SCWebLlm_Visible, g_SCWebLlm_RailDrag, g_SCWebLlm_ContentRect
    if !g_SCWebLlm_Visible
        return
    rec := ScWebLlm_IsResizeRailHwnd(hwnd)
    if !(rec is Map)
        return
    mode := rec.Has("mode") ? String(rec["mode"]) : ""
    if (mode = "trailing") {
        lastSid := ScWebLlm_NormalizeSiteId(rec.Get("leftSid", ""))
        if (lastSid = "")
            return
        siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
        embedWCss := 0
        if (g_SCWebLlm_ContentRect is Map) {
            cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
            if (cssW > 0)
                embedWCss := cssW
        }
        others := ScWebLlm_ComputeOthersStripWidth(siteIds, embedWCss)
        fill := (embedWCss > 0) ? ScWebLlm_ComputeStripFillExtraCss(siteIds, embedWCss) : 0
        slotCss := 0
        if (fill > 0 && embedWCss > others)
            slotCss := embedWCss - others
        MouseGetPos(&mx, &my)
        g_SCWebLlm_RailDrag := Map(
            "mode", "trailing",
            "left", lastSid,
            "railKey", "__trailing__",
            "startX", mx,
            "startLeft", ScWebLlm_ResolveColumnWidth(lastSid, siteIds, 0),
            "slotCss", slotCss
        )
        rec["dragging"] := true
        rec["raised"] := false
        rec["paintSig"] := ""
        g_SCWebLlm_RailDrag["zRaised"] := false
        try ScWebLlm_ApplyRailDragLayout()
        catch as e {
            ScWebLlm_Catch(e)
        }
        ScWebLlm_PushColumnLayoutToWeb(false, true)
        SetTimer(ScWebLlm_ResizeRailDragTick, 16)
        return
    }
    leftSid := rec.Has("leftSid") ? rec["leftSid"] : ""
    rightSid := rec.Has("rightSid") ? rec["rightSid"] : ""
    if (leftSid = "" || rightSid = "")
        return
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    MouseGetPos(&mx, &my)
    g_SCWebLlm_RailDrag := Map(
        "left", leftSid,
        "right", rightSid,
        "railKey", leftSid,
        "startX", mx,
        "startLeft", ScWebLlm_ResolveColumnWidth(leftSid, siteIds, 0),
        "startRight", ScWebLlm_ResolveColumnWidth(rightSid, siteIds, 0)
    )
    rec["dragging"] := true
    rec["raised"] := false
    rec["paintSig"] := ""
    g_SCWebLlm_RailDrag["zRaised"] := false
    try ScWebLlm_ApplyRailDragLayout()
    catch as e {
        ScWebLlm_Catch(e)
    }
    ScWebLlm_PushColumnLayoutToWeb(false, true)
    SetTimer(ScWebLlm_ResizeRailDragTick, 16)
}

ScWebLlm_ResizeRailDragTick() {
    global g_SCWebLlm_RailDrag, g_SCWebLlm_ColumnWidths, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ResizeRails
    if !(g_SCWebLlm_RailDrag is Map) {
        SetTimer(ScWebLlm_ResizeRailDragTick, 0)
        return
    }
    if !GetKeyState("LButton", "P") {
        SetTimer(ScWebLlm_ResizeRailDragTick, 0)
        ScWebLlm_FinishRailDrag()
        try SearchCenterWebLlm_ApplyBounds()
        catch as e {
            ScWebLlm_Catch(e)
        }
        ScWebLlm_PushColumnLayoutToWeb(true, false)
        return
    }
    MouseGetPos(&mx, &my)
    if (g_SCWebLlm_RailDrag.Get("mode", "") = "trailing") {
        deltaCss := ScWebLlm_PhysicalDeltaToCss(mx - Integer(g_SCWebLlm_RailDrag["startX"]))
        lastSid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_RailDrag["left"])
        nextBase := Max(ScWebLlm_MinColumnWidth(), Integer(g_SCWebLlm_RailDrag["startLeft"]) + deltaCss)
        slotCss := Integer(g_SCWebLlm_RailDrag.Get("slotCss", 0))
        if (slotCss > 0)
            nextBase := Min(nextBase, slotCss)
        if !(g_SCWebLlm_ColumnWidths is Map)
            g_SCWebLlm_ColumnWidths := Map()
        g_SCWebLlm_ColumnWidths[lastSid] := nextBase
        try ScWebLlm_ApplyRailDragLayout()
        catch as e {
            ScWebLlm_Catch(e)
        }
        ScWebLlm_PushColumnLayoutToWebThrottled(false, true)
        return
    }
    deltaCss := ScWebLlm_PhysicalDeltaToCss(mx - Integer(g_SCWebLlm_RailDrag["startX"]))
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    pair := Integer(g_SCWebLlm_RailDrag["startLeft"]) + Integer(g_SCWebLlm_RailDrag["startRight"])
    nextLeft := Max(ScWebLlm_MinColumnWidth(), Integer(g_SCWebLlm_RailDrag["startLeft"]) + deltaCss)
    nextRight := pair - nextLeft
    if (nextRight < ScWebLlm_MinColumnWidth()) {
        nextRight := ScWebLlm_MinColumnWidth()
        nextLeft := pair - nextRight
    }
    left := String(g_SCWebLlm_RailDrag["left"])
    right := String(g_SCWebLlm_RailDrag["right"])
    if !(g_SCWebLlm_ColumnWidths is Map)
        g_SCWebLlm_ColumnWidths := Map()
    g_SCWebLlm_ColumnWidths[left] := nextLeft
    g_SCWebLlm_ColumnWidths[right] := nextRight
    try ScWebLlm_ApplyRailDragLayout()
    catch as e {
        ScWebLlm_Catch(e)
    }
    ScWebLlm_PushColumnLayoutToWebThrottled(false, true)
}

ScWebLlm_FinishRailDrag() {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_RailDrag, g_SCWebLlm_ChildHostBoundsCache, g_SCWebLlm_SiteBoundsSig
    global g_SCWebLlm_RailLayoutPushDue, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_EdgeRails
    for , railRec in g_SCWebLlm_ResizeRails {
        if !(railRec is Map)
            continue
        railRec["dragging"] := false
        railRec["raised"] := false
        railRec["paintSig"] := ""
        railHwnd := railRec.Has("hwnd") ? Integer(railRec["hwnd"]) : 0
        if railHwnd && g_SCWebLlm_ChildHostBoundsCache.Has(railHwnd)
            g_SCWebLlm_ChildHostBoundsCache.Delete(railHwnd)
    }
    if (g_SCWebLlm_EdgeRails is Map) {
        for , railRec in g_SCWebLlm_EdgeRails {
            if !(railRec is Map)
                continue
            railRec["dragging"] := false
            railRec["raised"] := false
            railRec["paintSig"] := ""
            railHwnd := railRec.Has("hwnd") ? Integer(railRec["hwnd"]) : 0
            if railHwnd && g_SCWebLlm_ChildHostBoundsCache.Has(railHwnd)
                g_SCWebLlm_ChildHostBoundsCache.Delete(railHwnd)
        }
    }
    g_SCWebLlm_RailDrag := 0
    g_SCWebLlm_SiteBoundsSig := Map()
    g_SCWebLlm_RailLayoutPushDue := 0
    g_SCWebLlm_LastBoundsKey := ""
}

ScWebLlm_ApplyRailDragLayout() {
    global g_SCWebLlm_LastBoundsKey
    g_SCWebLlm_LastBoundsKey := ""
    SearchCenterWebLlm_ApplyBounds()
}

ScWebLlm_PushColumnLayoutToWebThrottled(persist := false, dragging := false) {
    global g_SCWebLlm_RailLayoutPushDue
    if !dragging {
        g_SCWebLlm_RailLayoutPushDue := 0
        ScWebLlm_PushColumnLayoutToWeb(persist, false)
        return
    }
    if g_SCWebLlm_RailLayoutPushDue
        return
    g_SCWebLlm_RailLayoutPushDue := 1
    SetTimer(ScWebLlm_PushColumnLayoutToWebDragTick.Bind(!!persist), -40)
}

ScWebLlm_PushColumnLayoutToWebDragTick(persist) {
    global g_SCWebLlm_RailLayoutPushDue, g_SCWebLlm_RailDrag
    g_SCWebLlm_RailLayoutPushDue := 0
    if !(g_SCWebLlm_RailDrag is Map)
        return
    ScWebLlm_PushColumnLayoutToWeb(persist, true)
}

ScWebLlm_PushColumnLayoutToWeb(persist := false, dragging := false) {
    global g_SCWebLlm_ScrollX, g_SCWebLlm_ColumnWidths, g_SCWebLlm_RailDrag, g_SCWebLlm_LastColFillCss
    if !FuncExists("ScWebLlm_PostJsonToHost") && !FuncExists("SCWV_PostJson")
        return
    if !dragging && (g_SCWebLlm_RailDrag is Map)
        dragging := true
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    cols := []
    lastSid := siteIds.Length ? siteIds[siteIds.Length] : ""
    fillExtra := Integer(g_SCWebLlm_LastColFillCss)
    for sid in siteIds {
        w := ScWebLlm_ResolveColumnWidth(sid, siteIds, 0)
        if (fillExtra > 0 && sid = lastSid)
            w += fillExtra
        cols.Push(Map("id", sid, "width", w))
    }
    payload := Map(
        "type", "webLlmColumnLayoutState",
        "scrollX", g_SCWebLlm_ScrollX,
        "columns", cols,
        "fillExtra", fillExtra,
        "persist", !!persist,
        "dragging", !!dragging
    )
    try {
        if FuncExists("ScWebLlm_PostJsonToHost")
            ScWebLlm_PostJsonToHost(payload)
        else if FuncExists("SCWV_PostJson")
            SCWV_PostJson(payload)
    }
    catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_PaintResizeRail(rec, hitWPhys, hPhys) {
    if !(rec is Map)
        return
    dragging := !!rec.Get("dragging", false)
    focused := !!rec.Get("focused", false) && !dragging
    hitW := Max(1, Integer(hitWPhys))
    h := Max(1, Integer(hPhys))
    sig := (dragging ? "d" : (focused ? "f" : "i")) . "|" . hitW . "|" . h
    if (rec.Get("paintSig", "") = sig)
        return
    rec["paintSig"] := sig
    g := rec.Has("gui") ? rec["gui"] : 0
    line := rec.Has("lineCtrl") ? rec["lineCtrl"] : 0
    if dragging {
        if IsObject(g) {
            try g.BackColor := "FF8D2A"
            catch as e {
                ScWebLlm_Catch(e)
            }
            try WinSetTransparent(148, g)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        if IsObject(line) {
            try line.Visible := false
            catch {
            }
        }
    } else {
        if IsObject(g) {
            try WinSetTransparent(255, g)
            catch {
            }
        }
        lineWCss := focused ? ScWebLlm_FocusRailLineCss() : 2
        lineW := Max(1, ScWebLlm_CssToPhysical(lineWCss))
        lineX := Max(0, (hitW - lineW) // 2)
        lineColor := focused ? "FF8D2A" : "D97706"
        if IsObject(g) {
            try g.BackColor := "0b1220"
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        if IsObject(line) {
            ; 焦点高亮由 HTML 玻璃框动画承担，拖条仅在非焦点时保留细分隔线
            if focused {
                try line.Visible := false
                catch {
                }
            } else {
                try line.Opt("+Background" . lineColor)
                catch {
                }
                try {
                    lineWIdle := Max(1, ScWebLlm_CssToPhysical(1))
                    lineXIdle := Max(0, (hitW - lineWIdle) // 2)
                    line.Move(lineXIdle, 0, lineWIdle, h)
                    line.Visible := true
                } catch as e {
                    ScWebLlm_Catch(e)
                }
            }
        }
    }
}

SearchCenterWebLlm_ApplyFocusRails(siteId := "") {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_RailDrag, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_EdgeRails
    if ScWebLlm_IsRailDragging()
        return
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    for , rec in g_SCWebLlm_ResizeRails {
        if !(rec is Map)
            continue
        leftSid := ScWebLlm_NormalizeSiteId(rec.Get("leftSid", ""))
        rightSid := ScWebLlm_NormalizeSiteId(rec.Get("rightSid", ""))
        rec["focused"] := (sid != "" && !rec.Get("dragging", false) && (leftSid = sid || rightSid = sid))
        rec["paintSig"] := ""
        railHwnd := Integer(rec.Get("hwnd", 0))
        if !railHwnd
            continue
        try WinGetClientPos(, , &rw, &rh, railHwnd)
        catch {
            rw := 0, rh := 0
        }
        if (rw > 0 && rh > 0)
            SearchCenterWebLlm_PaintResizeRail(rec, rw, rh)
    }
    if (g_SCWebLlm_EdgeRails is Map) && g_SCWebLlm_EdgeRails.Has("trailing") {
        rec := g_SCWebLlm_EdgeRails["trailing"]
        if (rec is Map) {
            lastSid := ScWebLlm_NormalizeSiteId(rec.Get("leftSid", ""))
            rec["focused"] := (sid != "" && sid = lastSid && !rec.Get("dragging", false))
            rec["paintSig"] := ""
            railHwnd := Integer(rec.Get("hwnd", 0))
            if railHwnd {
                try WinGetClientPos(, , &rw, &rh, railHwnd)
                catch {
                    rw := 0, rh := 0
                }
                if (rw > 0 && rh > 0)
                    SearchCenterWebLlm_PaintResizeRail(rec, rw, rh)
            }
        }
    }
}

SearchCenterWebLlm_PulseFocusSite(siteId, durationMs := 0) {
    SearchCenterWebLlm_ApplyFocusRails(siteId)
}

SearchCenterWebLlm_EnsureResizeRail(parentHwnd, leftSid, rightSid) {
    global g_SCWebLlm_ResizeRails
    key := ScWebLlm_NormalizeSiteId(leftSid)
    rightNorm := ScWebLlm_NormalizeSiteId(rightSid)
    if (key = "" || rightNorm = "")
        return 0
    if g_SCWebLlm_ResizeRails.Has(key) {
        rec := g_SCWebLlm_ResizeRails[key]
        rec["rightSid"] := rightNorm
        return rec
    }
    ScWebLlm_InstallResizeRailInputHook()
    created := SearchCenterWebLlm_CreateChildHostGui(Integer(parentHwnd), "0b1220")
    if !(created is Map) || !created.Has("hwnd")
        return 0
    g := created["gui"]
    try g.BackColor := "0b1220"
    catch {
    }
    line := 0
    lineW := Max(1, ScWebLlm_CssToPhysical(2))
    try line := g.Add("Text", "x0 y0 w" . lineW . " h100 +BackgroundD97706", "")
    catch as e {
        ScWebLlm_Catch(e)
    }
    rec := Map("gui", g, "hwnd", created["hwnd"], "leftSid", key, "rightSid", rightNorm, "lineCtrl", line, "dragging", false, "focused", false)
    g_SCWebLlm_ResizeRails[key] := rec
    return rec
}

SearchCenterWebLlm_EnsureEdgeRail(parentHwnd, edgeKey) {
    global g_SCWebLlm_EdgeRails
    key := Trim(String(edgeKey))
    if (key = "")
        return 0
    if !(g_SCWebLlm_EdgeRails is Map)
        g_SCWebLlm_EdgeRails := Map()
    if g_SCWebLlm_EdgeRails.Has(key) {
        return g_SCWebLlm_EdgeRails[key]
    }
    ScWebLlm_InstallResizeRailInputHook()
    created := SearchCenterWebLlm_CreateChildHostGui(Integer(parentHwnd), "0b1220")
    if !(created is Map) || !created.Has("hwnd")
        return 0
    g := created["gui"]
    try g.BackColor := "0b1220"
    catch {
    }
    line := 0
    lineW := Max(1, ScWebLlm_CssToPhysical(2))
    try line := g.Add("Text", "x0 y0 w" . lineW . " h100 +BackgroundD97706", "")
    catch as e {
        ScWebLlm_Catch(e)
    }
    rec := Map("gui", g, "hwnd", created["hwnd"], "edgeKey", key, "lineCtrl", line, "dragging", false, "focused", false)
    g_SCWebLlm_EdgeRails[key] := rec
    return rec
}

SearchCenterWebLlm_EnsureTrailingRail(parentHwnd, lastSid) {
    global g_SCWebLlm_EdgeRails
    key := "trailing"
    sid := ScWebLlm_NormalizeSiteId(lastSid)
    if !(g_SCWebLlm_EdgeRails is Map)
        g_SCWebLlm_EdgeRails := Map()
    if g_SCWebLlm_EdgeRails.Has(key) {
        rec := g_SCWebLlm_EdgeRails[key]
        rec["leftSid"] := sid
        return rec
    }
    ScWebLlm_InstallResizeRailInputHook()
    created := SearchCenterWebLlm_CreateChildHostGui(Integer(parentHwnd), "0b1220")
    if !(created is Map) || !created.Has("hwnd")
        return 0
    g := created["gui"]
    try g.BackColor := "0b1220"
    catch {
    }
    line := 0
    lineW := Max(1, ScWebLlm_CssToPhysical(2))
    try line := g.Add("Text", "x0 y0 w" . lineW . " h100 +BackgroundD97706", "")
    catch as e {
        ScWebLlm_Catch(e)
    }
    rec := Map(
        "gui", g,
        "hwnd", created["hwnd"],
        "edgeKey", key,
        "mode", "trailing",
        "leftSid", sid,
        "draggable", true,
        "lineCtrl", line,
        "dragging", false,
        "focused", false
    )
    g_SCWebLlm_EdgeRails[key] := rec
    return rec
}

SearchCenterWebLlm_ApplyResizeRails(siteIds, embedLeft, embedTop, embedW, embedH, parentHwnd, lastColFillCss := 0) {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_Visible, g_SCWebLlm_RailDrag, g_SCWebLlm_ActiveSiteId
    if !g_SCWebLlm_Visible || siteIds.Length < 2 {
        for , rec in g_SCWebLlm_ResizeRails {
            if (rec is Map) && rec.Has("hwnd") && rec["hwnd"]
                SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false, parentHwnd)
        }
        return
    }
    activeSid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    railT := embedTop
    railH := Max(140, Integer(embedH))
    gapPhys := ScWebLlm_CssToPhysical(ScWebLlm_ColumnGap())
    idleHit := ScWebLlm_CssToPhysical(ScWebLlm_IdleRailHitCss())
    dragW := ScWebLlm_CssToPhysical(ScWebLlm_ColumnGapDragCss())
    used := Map()
    railHwnds := []
    dragRailHwnd := 0
    Loop siteIds.Length - 1 {
        idx := A_Index - 1
        leftSid := siteIds[A_Index]
        rightSid := siteIds[A_Index + 1]
        leftNorm := ScWebLlm_NormalizeSiteId(leftSid)
        rightNorm := ScWebLlm_NormalizeSiteId(rightSid)
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        if !ScWebLlm_ComputeSiteColumnLayout(siteIds, "", embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, idx, lastColFillCss)
            continue
        railKey := leftNorm
        recDragging := ScWebLlm_IsRailDragging() && (g_SCWebLlm_RailDrag.Get("railKey", "") = railKey)
        isFocusRail := (activeSid != "" && (leftNorm = activeSid || rightNorm = activeSid))
        hitW := recDragging ? dragW : idleHit
        gapStart := colL + colW
        railX := gapStart + (gapPhys - hitW) // 2
        showRail := (railX + hitW > embedLeft && railX < embedLeft + embedW)
        rec := SearchCenterWebLlm_EnsureResizeRail(parentHwnd, leftSid, rightSid)
        if !(rec is Map) || !rec.Has("hwnd")
            continue
        rec["dragging"] := recDragging
        rec["focused"] := isFocusRail && !recDragging
        if !recDragging {
            rec["raised"] := false
            rec["paintSig"] := ""
        }
        SearchCenterWebLlm_PositionChildHost(rec["hwnd"], railX, railT, hitW, railH, showRail, parentHwnd)
        if showRail {
            SearchCenterWebLlm_PaintResizeRail(rec, hitW, railH)
            railHwnds.Push(rec["hwnd"])
            if recDragging
                dragRailHwnd := rec["hwnd"]
        }
        used[railKey] := true
    }
    global g_SCWebLlm_EdgeRails
    edgeUsed := Map()
    edgeHit := idleHit
    if siteIds.Length {
        lastIdx := siteIds.Length - 1
        lastSid := siteIds[siteIds.Length]
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        if ScWebLlm_ComputeSiteColumnLayout(siteIds, "", embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, lastIdx, lastColFillCss) {
            rec := SearchCenterWebLlm_EnsureTrailingRail(parentHwnd, lastSid)
            if (rec is Map) && rec.Has("hwnd") {
                recDragging := ScWebLlm_IsRailDragging() && (g_SCWebLlm_RailDrag.Get("railKey", "") = "__trailing__")
                isFocusRail := (activeSid != "" && ScWebLlm_NormalizeSiteId(lastSid) = activeSid)
                hitW := recDragging ? dragW : idleHit
                embedRight := embedLeft + embedW
                edgeRight := embedRight
                if (lastColFillCss > 0) {
                    edgeRight := embedRight
                } else {
                    visL := 0
                    visW := 0
                    if ScWebLlm_ComputeColumnVisibleSegment(colL, colW, embedLeft, embedW, &visL, &visW)
                        edgeRight := visL + visW
                    else
                        edgeRight := Min(colL + colW, embedRight)
                }
                railX := edgeRight - (hitW // 2)
                if (lastColFillCss > 0)
                    railX := embedRight - hitW
                if (railX + hitW > embedRight)
                    railX := embedRight - hitW
                if (railX < embedLeft)
                    railX := embedLeft
                showRail := (railX + hitW > embedLeft && railX < embedRight)
                rec["dragging"] := recDragging
                rec["focused"] := false
                rec["paintSig"] := ""
                SearchCenterWebLlm_PositionChildHost(rec["hwnd"], railX, railT, hitW, railH, showRail, parentHwnd)
                if showRail {
                    SearchCenterWebLlm_PaintResizeRail(rec, hitW, railH)
                    railHwnds.Push(rec["hwnd"])
                    if recDragging
                        dragRailHwnd := rec["hwnd"]
                }
                edgeUsed["trailing"] := true
            }
        }
    }
    if (g_SCWebLlm_EdgeRails is Map) {
        for key, rec in g_SCWebLlm_EdgeRails {
            if edgeUsed.Has(key) || !(rec is Map) || !rec.Has("hwnd") || !rec["hwnd"]
                continue
            rec["focused"] := false
            rec["paintSig"] := ""
            SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false, parentHwnd)
        }
    }
    if dragRailHwnd {
        if !(g_SCWebLlm_RailDrag is Map) || !g_SCWebLlm_RailDrag.Get("zRaised", false) {
            ScWebLlm_RaiseResizeRailTop(dragRailHwnd)
            if (g_SCWebLlm_RailDrag is Map)
                g_SCWebLlm_RailDrag["zRaised"] := true
        }
    } else if railHwnds.Length {
        ScWebLlm_RaiseResizeRailsTop(railHwnds)
    }
    for key, rec in g_SCWebLlm_ResizeRails {
        if used.Has(key) || !(rec is Map) || !rec.Has("hwnd") || !rec["hwnd"]
            continue
        SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false, parentHwnd)
    }
}

ScWebLlm_RaiseResizeRailsTop(railHwnds) {
    if !IsObject(railHwnds) || !railHwnds.Length
        return
    insertAfter := 0
    global g_SCWV_Ctrl
    if IsObject(g_SCWV_Ctrl) {
        try insertAfter := g_SCWV_Ctrl.ParentWindow
        catch {
        }
    }
    for hwnd in railHwnds {
        h := Integer(hwnd)
        if !h
            continue
        if insertAfter {
            try DllCall("SetWindowPos", "Ptr", h, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        try DllCall("SetWindowPos", "Ptr", h, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

SearchCenterWebLlm_RaiseResizeRailsAboveHosts() {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_EdgeRails
    hwnds := []
    for , rec in g_SCWebLlm_ResizeRails {
        if !(rec is Map) || !rec.Has("hwnd")
            continue
        h := Integer(rec["hwnd"])
        if !h
            continue
        try {
            WinGetClientPos(, , &w, &hh, h)
            if (w > 0 && hh > 0)
                hwnds.Push(h)
        } catch {
        }
    }
    if (g_SCWebLlm_EdgeRails is Map) {
        for , rec in g_SCWebLlm_EdgeRails {
            if !(rec is Map) || !rec.Has("hwnd")
                continue
            h := Integer(rec["hwnd"])
            if !h
                continue
            try {
                WinGetClientPos(, , &w, &hh, h)
                if (w > 0 && hh > 0)
                    hwnds.Push(h)
            } catch {
            }
        }
    }
    ScWebLlm_RaiseResizeRailsTop(hwnds)
}

ScWebLlm_FocusGlowWidthCss() {
    return 16
}

ScWebLlm_CreateFocusGlowHost(parentHwnd) {
    owner := Integer(parentHwnd)
    if !owner
        return 0
    try {
        g := Gui("-Caption -DPIScale", "SCWebLlmFocusGlow")
        g.Show("Hide x-32000 y-32000 w8 h8")
        hwnd := g.Hwnd
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")
        style := (style | 0x40000000 | 0x10000000) & ~0x80000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", style, "Ptr")
        if !DllCall("SetParent", "Ptr", hwnd, "Ptr", owner, "Ptr") {
            try g.Destroy()
            return 0
        }
        ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex | 0x80000 | 0x20, "Ptr")
        return Map("gui", g, "hwnd", hwnd)
    } catch as e {
        ScWebLlm_Catch(e)
        return 0
    }
}

ScWebLlm_PaintFocusGlowLayer(rec, side, w, h) {
    if !(rec is Map) || !rec.Has("hwnd") || !rec["hwnd"]
        return false
    w := Max(4, Integer(w))
    h := Max(8, Integer(h))
    sig := Trim(String(side)) . "|" . w . "|" . h
    if (rec.Get("paintSig", "") = sig)
        return true
    rec["paintSig"] := sig
    if !FuncExists("Gdip_CreateBitmap") || !FuncExists("UpdateLayeredWindow") {
        return false
    }
    pBitmap := 0
    G := 0
    hBitmap := 0
    hdc := 0
    try {
        pBitmap := Gdip_CreateBitmap(w, h)
        G := Gdip_GraphicsFromImage(pBitmap)
        Gdip_SetSmoothingMode(G, 4)
        Gdip_GraphicsClear(G, 0x00000000)
        inner := 0x22FFB060
        outer := 0x00FF8020
        if (Trim(String(side)) = "left") {
            pBrush := Gdip_CreateLineBrushFromRect(0, 0, w, h, outer, inner, 0)
        } else {
            pBrush := Gdip_CreateLineBrushFromRect(0, 0, w, h, inner, outer, 0)
        }
        Gdip_FillRectangle(G, pBrush, 0, 0, w, h)
        Gdip_DeleteBrush(pBrush)
        hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap, 0x00000000)
        hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
        obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hBitmap, "Ptr")
        UpdateLayeredWindow(rec["hwnd"], hdc, "", "", w, h, 255)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", obm, "Ptr")
        return true
    } catch as e {
        ScWebLlm_Catch(e)
        return false
    } finally {
        if hdc
            try DllCall("DeleteDC", "Ptr", hdc)
        if hBitmap
            try DllCall("DeleteObject", "UPtr", hBitmap)
        if G
            try Gdip_DeleteGraphics(G)
        if pBitmap
            try Gdip_DisposeImage(pBitmap)
    }
}

SearchCenterWebLlm_EnsureFocusGlowSide(parentHwnd, side) {
    global g_SCWebLlm_FocusGlow
    key := Trim(String(side))
    if (key = "")
        return 0
    if !(g_SCWebLlm_FocusGlow is Map)
        g_SCWebLlm_FocusGlow := Map()
    if g_SCWebLlm_FocusGlow.Has(key) {
        rec := g_SCWebLlm_FocusGlow[key]
        if (rec is Map) && rec.Has("hwnd") && rec["hwnd"]
            return rec
    }
    created := ScWebLlm_CreateFocusGlowHost(Integer(parentHwnd))
    if !(created is Map) || !created.Has("hwnd")
        return 0
    rec := Map("gui", created["gui"], "hwnd", created["hwnd"], "side", key, "paintSig", "")
    g_SCWebLlm_FocusGlow[key] := rec
    return rec
}

SearchCenterWebLlm_HideFocusGlow(parentHwnd := 0) {
    global g_SCWebLlm_FocusGlow, g_SCWebLlm_FocusGlowSig
    g_SCWebLlm_FocusGlowSig := ""
    if !(g_SCWebLlm_FocusGlow is Map)
        return
    ph := Integer(parentHwnd)
    for , rec in g_SCWebLlm_FocusGlow {
        if !(rec is Map) || !rec.Has("hwnd") || !rec["hwnd"]
            continue
        SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false, ph)
    }
}

ScWebLlm_RaiseFocusGlowTop() {
    global g_SCWebLlm_FocusGlow
    if !(g_SCWebLlm_FocusGlow is Map)
        return
    hwnds := []
    for , rec in g_SCWebLlm_FocusGlow {
        if !(rec is Map) || !rec.Has("hwnd") || !rec["hwnd"]
            continue
        h := Integer(rec["hwnd"])
        try {
            WinGetClientPos(, , &w, &hh, h)
            if (w > 0 && hh > 0)
                hwnds.Push(h)
        } catch {
        }
    }
    if hwnds.Length
        ScWebLlm_RaiseResizeRailsTop(hwnds)
}

SearchCenterWebLlm_ApplyFocusGlow(siteIds, activeSiteId, embedLeft, embedTop, embedW, embedH, parentHwnd, lastColFillCss := 0) {
    global g_SCWebLlm_FocusGlowSig
    if ScWebLlm_IsUnifiedWorkbenchHost() {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    if !siteIds.Length || !parentHwnd {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    activeNorm := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (activeNorm = "") {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    activeIdx := 0
    for i, sid in siteIds {
        if (ScWebLlm_NormalizeSiteId(sid) = activeNorm) {
            activeIdx := i
            break
        }
    }
    if (activeIdx < 1) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    colL := 0
    colT := 0
    colW := 0
    colH := 0
    if !ScWebLlm_ComputeSiteColumnLayout(siteIds, activeNorm, embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, activeIdx - 1, lastColFillCss) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    visL := 0
    visW := 0
    if !ScWebLlm_ComputeColumnVisibleSegment(colL, colW, embedLeft, embedW, &visL, &visW) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    if (visW < 40 || colH < 80) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    activeRec := SearchCenterWebLlm_SiteRecord(activeNorm)
    if !(activeRec is Map) || !activeRec.Get("ready", false) || !IsObject(activeRec.Get("wv2", 0)) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    glowW := ScWebLlm_CssToPhysical(ScWebLlm_FocusGlowWidthCss())
    padY := ScWebLlm_CssToPhysical(14)
    glowH := Max(ScWebLlm_CssToPhysical(72), colH - padY * 2)
    glowT := colT + padY
    leftX := visL
    rightX := visL + visW - glowW
    sig := leftX . "x" . rightX . "x" . glowT . "x" . glowW . "x" . glowH . "x" . activeNorm
    if (sig = g_SCWebLlm_FocusGlowSig)
        return
    g_SCWebLlm_FocusGlowSig := sig
    if (rightX < leftX || glowW <= 0) {
        SearchCenterWebLlm_HideFocusGlow(parentHwnd)
        return
    }
    leftRec := SearchCenterWebLlm_EnsureFocusGlowSide(parentHwnd, "left")
    rightRec := SearchCenterWebLlm_EnsureFocusGlowSide(parentHwnd, "right")
    if (leftRec is Map) && leftRec.Has("hwnd") {
        SearchCenterWebLlm_PositionChildHost(leftRec["hwnd"], leftX, glowT, glowW, glowH, true, parentHwnd)
        ScWebLlm_PaintFocusGlowLayer(leftRec, "left", glowW, glowH)
    }
    if (rightRec is Map) && rightRec.Has("hwnd") {
        SearchCenterWebLlm_PositionChildHost(rightRec["hwnd"], rightX, glowT, glowW, glowH, true, parentHwnd)
        ScWebLlm_PaintFocusGlowLayer(rightRec, "right", glowW, glowH)
    }
    ScWebLlm_RaiseFocusGlowTop()
}

SearchCenterWebLlm_HideResizeRails() {
    global g_SCWebLlm_ResizeRails, g_SCWebLlm_RailDrag, g_SCWebLlm_EdgeRails
    SearchCenterWebLlm_HideFocusGlow()
    g_SCWebLlm_RailDrag := 0
    SetTimer(ScWebLlm_ResizeRailDragTick, 0)
    for , rec in g_SCWebLlm_ResizeRails {
        if !(rec is Map)
            continue
        rec["dragging"] := false
        rec["focused"] := false
        rec["raised"] := false
        rec["paintSig"] := ""
        if rec.Has("hwnd") && rec["hwnd"]
            SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false)
    }
    if (g_SCWebLlm_EdgeRails is Map) {
        for , rec in g_SCWebLlm_EdgeRails {
            if !(rec is Map)
                continue
            rec["focused"] := false
            rec["paintSig"] := ""
            if rec.Has("hwnd") && rec["hwnd"]
                SearchCenterWebLlm_PositionChildHost(rec["hwnd"], 0, 0, 0, 0, false)
        }
    }
}

; 与 NiumaMobileBrowser（网络搜索手机浏览器）保持一致
ScWebLlm_MobileUserAgent() {
    return "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
}

ScWebLlm_ShouldUseMobileEmulation(siteId := "") {
    ua := ScWebLlm_SiteUaMode(siteId)
    if (ua = "mobile")
        return true
    if (ua = "desktop")
        return false
    ; default：Perplexity/Cloudflare 等对 partial mobile spoof 敏感
    return (ScWebLlm_NormalizeSiteId(siteId) != "perplexity")
}

ScWebLlm_ShouldNavigateKeywordDirect(siteId := "", keyword := "") {
    kw := Trim(String(keyword))
    if (kw = "" || InStr(kw, "://"))
        return false
    return true
}

ScWebLlm_NeedsKeywordInject(siteId := "") {
    mode := ScWebLlm_SiteQueryMode(siteId)
    if (mode = "inject" || mode = "url_then_inject")
        return true
    if (mode = "url" || mode = "manual")
        return false
    return (ScWebLlm_NormalizeSiteId(siteId) != "grok")
}

ScWebLlm_JsSingleQuote(s) {
    t := StrReplace(String(s), "\", "\\")
    t := StrReplace(t, "'", "\'")
    t := StrReplace(t, "`r`n", "\n")
    t := StrReplace(t, "`n", "\n")
    t := StrReplace(t, "`r", "\n")
    return "'" . t . "'"
}

ScWebLlm_QueuePendingKeyword(siteId, keyword) {
    global g_SCWebLlm_PendingKeywords
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return
    if !(g_SCWebLlm_PendingKeywords is Map)
        g_SCWebLlm_PendingKeywords := Map()
    g_SCWebLlm_PendingKeywords[sid] := kw
}

ScWebLlm_ClearPendingKeyword(siteId := "") {
    global g_SCWebLlm_PendingKeywords
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if !(g_SCWebLlm_PendingKeywords is Map) || (sid = "")
        return
    try g_SCWebLlm_PendingKeywords.Delete(sid)
    catch {
    }
}

ScWebLlm_BuildSubmitComposerScript(keyword, siteId := "") {
    q := ScWebLlm_JsSingleQuote(keyword)
    sid := ScWebLlm_JsSingleQuote(ScWebLlm_NormalizeSiteId(siteId))
    return "(function(){try{var txt=" . q . ",siteId=" . sid . ";"
        . "function vis(el){if(!el||el.disabled||el.readOnly||el.type==='hidden')return false;"
        . "var s=window.getComputedStyle?getComputedStyle(el):null;"
        . "if(s&&(s.display==='none'||s.visibility==='hidden'||Number(s.opacity||1)<0.05))return false;"
        . "var r=el.getBoundingClientRect();"
        . "if(r.width<28||r.height<8)return false;"
        . "if(r.bottom<0||r.top>(window.innerHeight||document.documentElement.clientHeight||800))return false;"
        . "return true;}"
        . "function readText(el){if(!el)return '';"
        . "var tag=(el.tagName||'').toLowerCase();"
        . "if(tag==='input'||tag==='textarea')return String(el.value||'');"
        . "return String(el.innerText||el.textContent||'');}"
        . "function notifyInput(el,data){"
        . "try{el.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,cancelable:true,inputType:'insertText',data:data}));}catch(e){}"
        . "try{el.dispatchEvent(new InputEvent('input',{bubbles:true,cancelable:true,inputType:'insertText',data:data}));}catch(e){"
        . "try{el.dispatchEvent(new Event('input',{bubbles:true}));}catch(e2){}}"
        . "try{el.dispatchEvent(new Event('change',{bubbles:true}));}catch(e3){}}"
        . "function clickNode(btn){if(!btn)return;"
        . "try{btn.scrollIntoView({block:'nearest',inline:'nearest'});}catch(e){}"
        . "var r=btn.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2,o={bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy};"
        . "try{btn.dispatchEvent(new PointerEvent('pointerdown',Object.assign({},o,{pointerId:1,pointerType:'mouse',isPrimary:true})));}catch(e1){}"
        . "try{btn.dispatchEvent(new MouseEvent('mousedown',o));btn.dispatchEvent(new MouseEvent('mouseup',o));btn.dispatchEvent(new MouseEvent('click',o));}catch(e2){try{btn.click();}catch(e3){}}"
        . "try{btn.dispatchEvent(new PointerEvent('pointerup',Object.assign({},o,{pointerId:1,pointerType:'mouse',isPrimary:true})));}catch(e4){}}"
        . "function fillEditor(el,text){"
        . "var tag=(el.tagName||'').toLowerCase();"
        . "try{el.focus({preventScroll:true});}catch(e){try{el.focus();}catch(e2){}}"
        . "if(tag==='input'||tag==='textarea'){"
        . "var proto=tag==='textarea'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;"
        . "var desc=Object.getOwnPropertyDescriptor(proto,'value');"
        . "if(desc&&desc.set)desc.set.call(el,text);else el.value=text;"
        . "notifyInput(el,text);return true;}"
        . "if(el.isContentEditable||el.getAttribute('role')==='textbox'){"
        . "try{var dt=new DataTransfer();dt.setData('text/plain',text);"
        . "el.dispatchEvent(new ClipboardEvent('paste',{bubbles:true,cancelable:true,clipboardData:dt}));"
        . "notifyInput(el,text);if(readText(el).trim().length>=text.length*0.4)return true;}catch(eP){}"
        . "try{document.execCommand('selectAll',false,null);document.execCommand('insertText',false,text);"
        . "notifyInput(el,text);if(readText(el).trim().length>=text.length*0.4)return true;}catch(e3){}"
        . "try{el.textContent=text;notifyInput(el,text);return true;}catch(e4){return false;}}"
        . "return false;}"
        . "function findComposer(){var cands=[],sels=["
        . "'textarea','[contenteditable=true]','[contenteditable]','[role=textbox]',"
        . "'rich-textarea div[contenteditable]','div[contenteditable]',"
        . "'[aria-placeholder*=DeepSeek]','[aria-placeholder*=Gemini]','[aria-placeholder*=Ask]','[data-placeholder*=DeepSeek]','[data-placeholder*=Gemini]'];"
        . "sels.forEach(function(sel){try{document.querySelectorAll(sel).forEach(function(el){"
        . "if(!vis(el))return;var r=el.getBoundingClientRect();"
        . "cands.push({el:el,area:r.width*r.height,bottom:r.bottom});});}catch(e){}});"
        . "if(!cands.length)return null;"
        . "cands.sort(function(a,b){return b.bottom-a.bottom||b.area-a.area;});"
        . "return cands[0].el;}"
        . "function scoreSendBtn(btn,editor){"
        . "if(!btn||!vis(btn)||btn===editor)return -1;"
        . "if(btn.disabled||btn.getAttribute('aria-disabled')==='true')return -1;"
        . "var tag=(btn.tagName||'').toLowerCase();"
        . "if(tag!=='button'&&tag!=='a'&&btn.getAttribute('role')!=='button')return -1;"
        . "var blob=(btn.getAttribute('aria-label')||'')+' '+(btn.getAttribute('title')||'')+' '"
        . "+(btn.getAttribute('data-testid')||'')+' '+(btn.getAttribute('class')||'')+' '+(btn.textContent||'');"
        . "blob=blob.toLowerCase();"
        . "if(/attach|upload|上传|附件|语音|mic|voice|plus|paperclip|clip|image|photo|compass|file|发现|写作|搜索框/.test(blob))return -1;"
        . "var pts=0;"
        . "if(/send|submit|发送|提交|post message|post/.test(blob))pts+=90;"
        . "if(btn.querySelector('svg'))pts+=18;"
        . "var r=btn.getBoundingClientRect(),vw=window.innerWidth||800,vh=window.innerHeight||600;"
        . "if(r.width<14||r.height<14)return -1;"
        . "if(r.left<vw*0.18)pts-=80;"
        . "if(r.top>vh*0.42)pts+=22;"
        . "if(r.left>vw*0.68)pts+=58;"
        . "if(editor){var er=editor.getBoundingClientRect();"
        . "if(Math.abs(r.top-er.top)<130&&r.left>=er.left-24)pts+=34;}"
        . "if(r.width>=26&&r.width<=96&&r.height>=26&&r.height<=96)pts+=12;"
        . "return pts;}"
        . "function findSendButton(editor){"
        . "var sels=['[aria-label*=发送]','[aria-label*=Send]','[aria-label*=send]','[data-testid*=send]','button[aria-label*=Send]'];"
        . "var best=null,bestScore=0,si,nodes,ni,btn,sc;"
        . "for(si=0;si<sels.length;si++){try{nodes=document.querySelectorAll(sels[si]);}catch(e){nodes=[];}"
        . "for(ni=0;ni<nodes.length;ni++){btn=nodes[ni];sc=scoreSendBtn(btn,editor);if(sc>bestScore){bestScore=sc;best=btn;}}}"
        . "try{nodes=document.querySelectorAll('button,[role=button]');}catch(e2){nodes=[];}"
        . "for(ni=0;ni<nodes.length;ni++){btn=nodes[ni];sc=scoreSendBtn(btn,editor);if(sc>bestScore){bestScore=sc;best=btn;}}"
        . "return bestScore>=32?best:null;}"
        . "function fireEnter(el){if(!el)return;"
        . "['keydown','keypress','keyup'].forEach(function(tp){"
        . "try{el.dispatchEvent(new KeyboardEvent(tp,{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true}));}"
        . "catch(e){}});}"
        . "function sentOk(before,after){before=String(before||'').trim();after=String(after||'').trim();"
        . "if(!before)return after.length===0;"
        . "return after.length===0||after.length<before.length*0.35;}"
        . "function trySend(el,before,pass){"
        . "var btn=findSendButton(el);"
        . "if(btn){clickNode(btn);"
        . "setTimeout(function(){var after=readText(el);"
        . "if(sentOk(before,after))return;"
        . "if(pass<10)setTimeout(function(){trySend(el,before,pass+1);},siteId==='deepseek'||siteId==='gemini'?320:260);"
        . "else fireEnter(el);},siteId==='deepseek'||siteId==='gemini'?280:200);return;}"
        . "if(pass<10)setTimeout(function(){trySend(el,before,pass+1);},siteId==='deepseek'||siteId==='gemini'?320:260);"
        . "else fireEnter(el);}"
        . "function attempt(){"
        . "var el=findComposer();"
        . "if(!el)return false;"
        . "try{el.scrollIntoView({block:'nearest',inline:'nearest'});}catch(e){}"
        . "clickNode(el);"
        . "if(!fillEditor(el,txt))return false;"
        . "var before=readText(el);"
        . "setTimeout(function(){trySend(el,before,0);},siteId==='deepseek'||siteId==='gemini'?220:140);"
        . "return true;}"
        . "var tries=0;(function poll(){"
        . "if(attempt())return;"
        . "tries++;if(tries<20)setTimeout(poll,siteId==='deepseek'||siteId==='gemini'?360:320);})();"
        . "return 'ok';}catch(e){return 'err';}})();"
}

ScWebLlm_BuildSendOnlyRetryScript(siteId := "") {
    sid := ScWebLlm_JsSingleQuote(ScWebLlm_NormalizeSiteId(siteId))
    return "(function(){try{var siteId=" . sid . ";"
        . "function vis(el){if(!el)return false;var s=getComputedStyle(el);"
        . "if(s.display==='none'||s.visibility==='hidden')return false;"
        . "var r=el.getBoundingClientRect();return r.width>12&&r.height>12;}"
        . "function readText(el){if(!el)return '';var t=(el.tagName||'').toLowerCase();"
        . "return t==='input'||t==='textarea'?String(el.value||''):String(el.innerText||el.textContent||'');}"
        . "function clickNode(btn){if(!btn)return;"
        . "var r=btn.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2,o={bubbles:true,cancelable:true,view:window,clientX:cx,clientY:cy};"
        . "try{btn.dispatchEvent(new MouseEvent('mousedown',o));btn.dispatchEvent(new MouseEvent('mouseup',o));btn.dispatchEvent(new MouseEvent('click',o));}catch(e){try{btn.click();}catch(e2){}}}"
        . "var el=null,cands=[];"
        . "document.querySelectorAll('textarea,[contenteditable],[role=textbox]').forEach(function(n){"
        . "if(!vis(n))return;var r=n.getBoundingClientRect();cands.push({el:n,bottom:r.bottom});});"
        . "cands.sort(function(a,b){return b.bottom-a.bottom;});"
        . "if(cands.length)el=cands[0].el;"
        . "if(!el||readText(el).trim().length<2)return 'empty';"
        . "var best=null,score=0,vw=innerWidth||800;"
        . "document.querySelectorAll('button,[role=button]').forEach(function(btn){"
        . "if(!vis(btn)||btn.disabled)return;"
        . "var b=(btn.getAttribute('aria-label')||'')+' '+(btn.textContent||'');b=b.toLowerCase();"
        . "var pts=0;if(/send|发送|submit|提交/.test(b))pts+=80;"
        . "if(btn.querySelector('svg'))pts+=15;var r=btn.getBoundingClientRect();"
        . "if(r.left>vw*0.65)pts+=50;if(pts>score){score=pts;best=btn;}});"
        . "if(best&&score>=30){clickNode(best);return 'click';}"
        . "return 'miss';}catch(e){return 'err';}})();"
}

ScWebLlm_SubmitDelayForSite(siteId := "", baseMs := 650) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    extra := Integer(ScWebLlm_SiteCapability(sid, "submitDelayMs", 0))
    if (extra <= 0 && (sid = "deepseek" || sid = "gemini"))
        extra := 550
    return Max(120, Integer(baseMs) + extra)
}

ScWebLlm_ScheduleSubmitKeyword(siteId, keyword, delayMs := 500) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return
    ScWebLlm_QueuePendingKeyword(sid, kw)
    SetTimer(ScWebLlm_SubmitKeywordTick.Bind(sid, kw), -Max(120, Integer(delayMs)))
}

ScWebLlm_SubmitKeywordTick(siteId, keyword) {
    global g_SCWebLlm_PendingKeywords
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return
    if !(g_SCWebLlm_PendingKeywords is Map) || !g_SCWebLlm_PendingKeywords.Has(sid)
        return
    if (Trim(String(g_SCWebLlm_PendingKeywords[sid])) != kw)
        return
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) || !rec.Get("ready", false) || !IsObject(rec["wv2"])
        return
    js := ScWebLlm_BuildSubmitComposerScript(kw, sid)
    try rec["wv2"].ExecuteScriptAsync(js)
    catch as e {
        ScWebLlm_Catch(e)
        return
    }
    if ScWebLlm_NeedsKeywordInject(sid) {
        delayRetry := (sid = "deepseek" || sid = "gemini") ? 1800 : 1200
        SetTimer(ScWebLlm_SubmitKeywordSendRetry.Bind(sid, kw), -delayRetry)
    }
    ScWebLlm_ClearPendingKeyword(sid)
}

ScWebLlm_SubmitKeywordSendRetry(siteId, keyword) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) || !rec.Get("ready", false) || !IsObject(rec["wv2"])
        return
    js := ScWebLlm_BuildSendOnlyRetryScript(sid)
    try rec["wv2"].ExecuteScriptAsync(js)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_ResolveKeywordNavigateUrl(siteId, keyword) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return ""
    ; 内嵌对话站：只在首次打开时进首页，后续在同页注入追问，不走 ?q= 直达
    if ScWebLlm_NeedsKeywordInject(sid)
        return ScWebLlm_SiteHomeUrl(sid)
    if !ScWebLlm_ShouldNavigateKeywordDirect(sid, kw)
        return ScWebLlm_SiteHomeUrl(sid)
    url := ""
    if FuncExists("VoiceInputEffect_BuildSearchUrl") {
        try url := VoiceInputEffect_BuildSearchUrl(kw, sid)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if (url = "")
        url := ScWebLlm_SiteHomeUrl(sid)
    return url
}

ScWebLlm_SiteReadyForInject(siteId := "") {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    rec := SearchCenterWebLlm_SiteRecord(sid)
    return (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
}

ScWebLlm_SiteUsesIsolatedProfile(siteId := "") {
    return (ScWebLlm_SiteProfileMode(siteId) = "isolated")
}

ScWebLlm_BuildFocusComposerScript(siteId := "") {
    return "(function(){try{var cands=[];"
        . "document.querySelectorAll('textarea,[contenteditable],[role=textbox],input[type=text],input:not([type]),[data-testid*=input],[data-testid*=composer]').forEach(function(el){"
        . "if(!el||el.disabled||el.readOnly||el.type==='hidden')return;"
        . "var s=window.getComputedStyle?getComputedStyle(el):null;"
        . "if(s&&(s.display==='none'||s.visibility==='hidden'||Number(s.opacity||1)<0.05))return;"
        . "var r=el.getBoundingClientRect();"
        . "if(r.width<36||r.height<10)return;"
        . "if(r.bottom<0||r.top>(window.innerHeight||document.documentElement.clientHeight))return;"
        . "cands.push({el:el,area:r.width*r.height,bottom:r.bottom});});"
        . "if(!cands.length)return 'miss';"
        . "cands.sort(function(a,b){return b.bottom-a.bottom||b.area-a.area;});"
        . "var t=cands[0].el;try{t.scrollIntoView({block:'nearest',inline:'nearest'});}catch(e){}"
        . "try{t.focus({preventScroll:true});}catch(e){try{t.focus();}catch(e2){}}"
        . "try{t.click();}catch(e){}"
        . "return 'ok';}catch(e){return 'err';}})();"
}

SearchCenterWebLlm_FocusSiteInput(siteId) {
    if !ScWebLlm_AllowEmbedFocusSteal()
        return false
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) || !rec.Get("ready", false)
        return false
    hostHwnd := rec.Has("hostHwnd") ? Integer(rec["hostHwnd"]) : 0
    if hostHwnd {
        try DllCall("SetFocus", "Ptr", hostHwnd)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if IsObject(rec["ctrl"]) && FuncExists("WebView2_MoveFocusProgrammatic") {
        try WebView2_MoveFocusProgrammatic(rec["ctrl"])
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if !IsObject(rec["wv2"])
        return false
    js := ScWebLlm_BuildFocusComposerScript(sid)
    try rec["wv2"].ExecuteScriptAsync(js)
    catch as e {
        ScWebLlm_Catch(e)
        return false
    }
    return true
}

ScWebLlm_BuildInitScript(siteId := "") {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return ""
    sidJs := StrReplace(StrReplace(sid, "\", "\\"), "'", "\'")
    return "(function(){"
        . "var sid='" . sidJs . "',last=0;"
        . "function post(k){var n=Date.now();if(n-last<70)return;last=n;"
        . "try{if(window.chrome&&window.chrome.webview&&window.chrome.webview.postMessage)"
        . "window.chrome.webview.postMessage(JSON.stringify({type:'scWebLlmInteract',siteId:sid,kind:k||'event'}));"
        . "}catch(e){}}"
        . "document.addEventListener('pointerdown',function(){post('pointer');},true);"
        . "document.addEventListener('wheel',function(){post('wheel');},{capture:true,passive:true});"
        . "})();"
}

ScWebLlm_IsBlankEmbedUrl(url) {
    u := StrLower(Trim(String(url)))
    return (u = "" || u = "about:blank" || u = "about:blank#blocked")
}

ScWebLlm_ResolveStartUrl(siteId, navigateUrl := "") {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    targetUrl := Trim(String(navigateUrl))
    if (sid = "perplexity" && ScWebLlm_IsBlankEmbedUrl(targetUrl))
        return ScWebLlm_SiteHomeUrl(sid)
    if ScWebLlm_IsBlankEmbedUrl(targetUrl)
        targetUrl := SearchCenterWebLlm_SiteLastUrl(sid)
    if ScWebLlm_IsBlankEmbedUrl(targetUrl)
        targetUrl := ScWebLlm_SiteHomeUrl(sid)
    return targetUrl
}

ScWebLlm_MobileColumnCssWidth() {
    return 390
}

ScWebLlm_GetEmbedParentHwnd() {
    global g_SCWV_Gui
    if IsObject(g_SCWV_Gui) {
        try return g_SCWV_Gui.Hwnd
        catch {
        }
    }
    return 0
}

ScWebLlm_ResolveEmbedHostHwnd() {
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        h := Integer(g_SCWebLlm_ParentHwnd)
    if !h && IsObject(g_SCWV_Gui) {
        try h := g_SCWV_Gui.Hwnd
        catch {
        }
    }
    return h
}

SearchCenterWebLlm_SiteRecord(siteId) {
    global g_SCWebLlm_SiteHosts
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return 0
    if !g_SCWebLlm_SiteHosts.Has(sid)
        g_SCWebLlm_SiteHosts[sid] := Map(
            "siteId", sid,
            "hostGui", 0, "hostHwnd", 0,
            "ctrl", 0, "wv2", 0,
            "ready", false, "createInFlight", false,
            "createStarted", 0, "pendingCreateHost", 0,
            "lifecycleState", "none",
            "tokenNavCompleted", 0,
            "tokenWebMessage", 0,
            "tokenGotFocus", 0
        )
    return g_SCWebLlm_SiteHosts[sid]
}

SearchCenterWebLlm_SyncActiveGlobals() {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map) {
        g_SCWebLlm_Ctrl := 0
        g_SCWebLlm_WV2 := 0
        g_SCWebLlm_Ready := false
        g_SCWebLlm_TokenNavCompleted := 0
        return
    }
    g_SCWebLlm_Ctrl := rec.Has("ctrl") ? rec["ctrl"] : 0
    g_SCWebLlm_WV2 := rec.Has("wv2") ? rec["wv2"] : 0
    g_SCWebLlm_Ready := !!rec.Get("ready", false)
    g_SCWebLlm_TokenNavCompleted := rec.Has("tokenNavCompleted") ? rec["tokenNavCompleted"] : 0
}

SearchCenterWebLlm_ApplyMobileSettings(wv2, siteId := "") {
    if !IsObject(wv2)
        return
    try {
        s := wv2.Settings
        if IsObject(s) {
            if ScWebLlm_ShouldUseMobileEmulation(siteId)
                s.UserAgent := ScWebLlm_MobileUserAgent()
            s.AreDefaultContextMenusEnabled := true
            s.AreDevToolsEnabled := false
            s.IsStatusBarEnabled := false
            try s.IsWebMessageEnabled := true
            catch {
            }
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_ListLayoutSiteIds() {
    global SearchCenterSelectedEngines, g_SCWebLlm_MultiMobile, g_SCWebLlm_BroadcastSynced, g_SCWebLlm_LayoutSiteIds
    if !g_SCWebLlm_MultiMobile
        return ScWebLlm_DefaultOpenSiteIds()
    if ScWebLlm_IsUnifiedWorkbenchHost() {
        if IsObject(g_SCWebLlm_LayoutSiteIds) && g_SCWebLlm_LayoutSiteIds.Length > 0 {
            rawU := []
            for sid in g_SCWebLlm_LayoutSiteIds
                rawU.Push(sid)
            return ScWebLlm_NormalizeBroadcastSiteIds(rawU)
        }
        return []
    }
    raw := []
    if IsObject(g_SCWebLlm_LayoutSiteIds) && g_SCWebLlm_LayoutSiteIds.Length > 0 {
        for sid in g_SCWebLlm_LayoutSiteIds
            raw.Push(sid)
    } else if g_SCWebLlm_BroadcastSynced && IsObject(SearchCenterSelectedEngines) && SearchCenterSelectedEngines.Length > 0 {
        for eng in SearchCenterSelectedEngines
            raw.Push(eng)
    }
    return ScWebLlm_NormalizeBroadcastSiteIds(raw)
}

ScWebLlm_SyncBroadcastLayoutFromColumnIds(orderedIds) {
    global SearchCenterSelectedEngines, g_SCWebLlm_BroadcastSynced, g_SCWebLlm_LayoutSiteIds
    if !IsObject(orderedIds) || !orderedIds.Length
        return false
    normalized := ScWebLlm_NormalizeBroadcastSiteIds(orderedIds)
    if !normalized.Length
        return false
    g_SCWebLlm_LayoutSiteIds := normalized
    SearchCenterSelectedEngines := normalized.Clone()
    g_SCWebLlm_BroadcastSynced := true
    if FuncExists("_SCWV_SaveSelectedEngines") {
        try _SCWV_SaveSelectedEngines("ai", SearchCenterSelectedEngines)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return true
}

ScWebLlm_EnsureSiteInBroadcastLayout(siteId) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "" || !ScWebLlm_IsSiteEnabled(sid))
        return false
    for existing in SearchCenterWebLlm_ListLayoutSiteIds() {
        if (ScWebLlm_NormalizeSiteId(existing) = sid)
            return true
    }
    raw := []
    for existing in SearchCenterWebLlm_ListLayoutSiteIds()
        raw.Push(existing)
    raw.Push(sid)
    return ScWebLlm_SyncBroadcastLayoutFromColumnIds(raw)
}

ScWebLlm_Catch(err) {
    if FuncExists("NmerCatch")
        try NmerCatch(A_ThisFunc, err)
}

ScWebLlm_ShouldShowWebEmbed() {
    fn := "_SCWV_ShouldShowWebEmbed"
    if !FuncExists(fn)
        return false
    try {
        return !!(%fn%)()
    } catch as e {
        ScWebLlm_Catch(e)
        return false
    }
}

ScWebLlm_IsUnifiedWorkbenchHost() {
    global g_SCWebLlm_UnifiedHostActive
    if g_SCWebLlm_UnifiedHostActive
        return true
    if FuncExists("UnifiedWb_IsVisible") {
        try return UnifiedWb_IsVisible()
        catch {
        }
    }
    return false
}

ScWebLlm_UnifiedHasEmbedLayout() {
    global g_SCWebLlm_LayoutSiteIds
    return IsObject(g_SCWebLlm_LayoutSiteIds) && g_SCWebLlm_LayoutSiteIds.Length > 0
}

ScWebLlm_UnifiedEmbedBootstrapReady() {
    if !ScWebLlm_IsUnifiedWorkbenchHost()
        return true
    return ScWebLlm_UnifiedHasEmbedLayout()
}

ScWebLlm_UnifiedScheduleLayoutBootstrap(delayMs := 120) {
    global g_SCWebLlm_UnifiedLayoutBootstrapScheduled
    if g_SCWebLlm_UnifiedLayoutBootstrapScheduled
        return
    g_SCWebLlm_UnifiedLayoutBootstrapScheduled := true
    SetTimer(ScWebLlm_UnifiedLayoutBootstrapTick.Bind(), -Max(40, Integer(delayMs)))
}

ScWebLlm_UnifiedLayoutBootstrapTick(*) {
    global g_SCWebLlm_UnifiedLayoutBootstrapScheduled
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown() {
        g_SCWebLlm_UnifiedLayoutBootstrapScheduled := false
        return
    }
    g_SCWebLlm_UnifiedLayoutBootstrapScheduled := false
    if !ScWebLlm_IsUnifiedWorkbenchHost() || !FuncExists("UnifiedWb_IsVisible")
        return
    try visible := UnifiedWb_IsVisible()
    catch {
        return
    }
    if !visible
        return
    if ScWebLlm_IsUnifiedLayoutPaused()
        return
    if ScWebLlm_UnifiedEmbedBootstrapReady() {
        global g_SCWebLlm_UnifiedLayoutNudgeCount
        g_SCWebLlm_UnifiedLayoutNudgeCount := 0
        h := ScWebLlm_GetEmbedParentHwnd()
        if h {
            if FuncExists("UnifiedWb_EnsureAiEmbedLayering") {
                try UnifiedWb_EnsureAiEmbedLayering()
                catch {
                }
            } else {
                try SearchCenterWebLlm_ApplyBounds(h)
                catch as e {
                    ScWebLlm_Catch(e)
                }
            }
        }
        return
    }
    global g_SCWebLlm_UnifiedLayoutNudgeTick, g_SCWebLlm_UnifiedLayoutNudgeCount
    g_SCWebLlm_UnifiedLayoutNudgeCount := Integer(g_SCWebLlm_UnifiedLayoutNudgeCount) + 1
    if (g_SCWebLlm_UnifiedLayoutNudgeCount > 24)
        return
    nowTick := A_TickCount
    if (nowTick - Integer(g_SCWebLlm_UnifiedLayoutNudgeTick) >= 1800) {
        g_SCWebLlm_UnifiedLayoutNudgeTick := nowTick
        if FuncExists("UnifiedWb_PostJson") {
            try UnifiedWb_PostJson(Map("type", "hostOpenBootstrap", "reason", "native_layout_retry", "includeCli", false), true)
            catch {
            }
        }
    }
    delayMs := Min(2400, 220 + g_SCWebLlm_UnifiedLayoutNudgeCount * 80)
    ScWebLlm_UnifiedScheduleLayoutBootstrap(delayMs)
}

ScWebLlm_UnifiedMemoryTierCap() {
    static cached := 0
    if cached
        return cached
    memGb := 16
    try {
        memStatus := Buffer(64, 0)
        NumPut("UInt", 64, memStatus, 0)
        if DllCall("kernel32\GlobalMemoryStatusEx", "Ptr", memStatus) {
            totalPhys := NumGet(memStatus, 8, "UInt64")
            if (totalPhys > 0)
                memGb := Max(1, Round(totalPhys / (1024 * 1024 * 1024)))
        }
    } catch {
    }
    if (memGb <= 8)
        cached := 2
    else if (memGb <= 12)
        cached := 4
    else
        cached := 8
    return cached
}

ScWebLlm_UnifiedMaxActiveAiEmbedsConfigured() {
    default := 8
    maxCap := 8
    try {
        global ConfigFile
        if IsSet(ConfigFile) && ConfigFile != "" {
            v := IniRead(ConfigFile, "UnifiedWorkbench", "MaxActiveAiEmbeds", "8")
            n := Integer(v)
            if (n >= 1 && n <= maxCap)
                return n
        }
    } catch {
    }
    return default
}

ScWebLlm_UnifiedIgnoreMemoryTierCap() {
    try {
        global ConfigFile
        if IsSet(ConfigFile) && ConfigFile != "" {
            v := Trim(String(IniRead(ConfigFile, "UnifiedWorkbench", "IgnoreMemoryTierCap", "0")))
            return (v = "1" || StrLower(v) = "true" || StrLower(v) = "yes")
        }
    } catch {
    }
    return false
}

ScWebLlm_UnifiedMaxActiveAiEmbeds() {
    configured := ScWebLlm_UnifiedMaxActiveAiEmbedsConfigured()
    if ScWebLlm_UnifiedIgnoreMemoryTierCap()
        return configured
    tierCap := ScWebLlm_UnifiedMemoryTierCap()
    return Min(configured, tierCap)
}

ScWebLlm_UnifiedNotifySiteMemoryLevel(sid, shown := true) {
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) || !IsObject(rec.Get("wv2", 0))
        return
    try {
        if shown && FuncExists("WebView2_NotifyShown")
            WebView2_NotifyShown(rec["wv2"])
        else if !shown && FuncExists("WebView2_NotifyHidden")
            WebView2_NotifyHidden(rec["wv2"])
    } catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_UnifiedTrimExcessSiteHosts(maxKeep := 12) {
    global g_SCWebLlm_SiteHosts, g_SCWebLlm_LayoutSiteIds, g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_ActiveSiteId
    if !ScWebLlm_IsUnifiedWorkbenchHost() || !g_SCWebLlm_UnifiedMultiRectActive
        return
    if !(g_SCWebLlm_SiteHosts is Map)
        return
    layoutSet := Map()
    if IsObject(g_SCWebLlm_LayoutSiteIds) {
        for sid in g_SCWebLlm_LayoutSiteIds {
            sidNorm := ScWebLlm_NormalizeSiteId(sid)
            if (sidNorm != "")
                layoutSet[sidNorm] := true
        }
    }
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    count := g_SCWebLlm_SiteHosts.Count
    if (count <= maxKeep)
        return
    toDispose := []
    for sid, rec in g_SCWebLlm_SiteHosts {
        sidNorm := ScWebLlm_NormalizeSiteId(sid)
        if (sidNorm = "" || layoutSet.Has(sidNorm) || sidNorm = activeNorm)
            continue
        if !(rec is Map)
            continue
        toDispose.Push(sidNorm)
    }
    for sidNorm in toDispose {
        if (count <= maxKeep)
            break
        try SearchCenterWebLlm_DisposeSiteController(sidNorm)
        catch as e {
            ScWebLlm_Catch(e)
        }
        count -= 1
    }
}

ScWebLlm_ClearUnifiedMultiColumnRects() {
    global g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_UnifiedEmbedViewport
    g_SCWebLlm_UnifiedMultiRectActive := false
    g_SCWebLlm_UnifiedColumnRects := Map()
    g_SCWebLlm_UnifiedEmbedViewport := Map()
}

ScWebLlm_DisposeUnifiedOverlayHosts() {
    global g_SCWebLlm_SiteHosts, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ChildHostBoundsCache
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_ChildHostBoundsCache := Map()
    if !(g_SCWebLlm_SiteHosts is Map)
        return
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if IsObject(rec.Get("wv2", 0)) || IsObject(rec.Get("ctrl", 0)) {
            try SearchCenterWebLlm_DisposeSiteController(sid)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        if IsObject(rec["hostGui"]) {
            try rec["hostGui"].Destroy()
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        rec["hostGui"] := 0
        rec["hostHwnd"] := 0
        rec["ownerHwnd"] := 0
    }
}

SearchCenterWebLlm_UnifiedHasResumableSites() {
    global g_SCWebLlm_SiteHosts, g_SCWebLlm_UnifiedSuspendGen
    if !Integer(g_SCWebLlm_UnifiedSuspendGen)
        return false
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
            return true
    }
    return false
}

SearchCenterWebLlm_SuspendUnifiedEmbed() {
    global g_SCWebLlm_Visible, g_SCWebLlm_UnifiedSuspendGen, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ParentHwnd, g_SCWebLlm_UnifiedLayoutPaused
    g_SCWebLlm_UnifiedLayoutPaused := false
    g_SCWebLlm_UnifiedSuspendGen := Integer(g_SCWebLlm_UnifiedSuspendGen) + 1
    g_SCWebLlm_Visible := false
    g_SCWebLlm_LastBoundsKey := ""
    ScWebLlm_ClearUnifiedMultiColumnRects()
    ScWebLlm_EndEmbedFocusGuard()
    SetTimer(ScWebLlm_BoundsRetryTick, 0)
    parentHwnd := Integer(g_SCWebLlm_ParentHwnd)
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
        if hostHwnd
            SearchCenterWebLlm_PositionChildHost(hostHwnd, 0, 0, 0, 0, false, parentHwnd)
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
    }
    ScWebLlm_HideEmbedBackdrop()
    SearchCenterWebLlm_RestoreMainWebView()
}

SearchCenterWebLlm_ResumeUnifiedEmbed(parentHwnd := 0) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWebLlm_ContentRectReady, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_OwnerOverlay
    h := Integer(parentHwnd)
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ContentRectReady := false
    g_SCWebLlm_LastBoundsKey := ""
    SearchCenterWebLlm_LowerMainWebView()
    if FuncExists("ScWebLlm_UnifiedScheduleLayoutBootstrap")
        ScWebLlm_UnifiedScheduleLayoutBootstrap(60)
    return true
}

SearchCenterWebLlm_SetUnifiedEmbedLayoutPaused(paused := true) {
    global g_SCWebLlm_UnifiedLayoutPaused, g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible, g_SCWebLlm_SiteHosts
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ChildHostBoundsCache
    if !ScWebLlm_IsUnifiedWorkbenchHost()
        return false
    wantPause := !!paused
    if (wantPause = g_SCWebLlm_UnifiedLayoutPaused)
        return true
    g_SCWebLlm_UnifiedLayoutPaused := wantPause
    parentHwnd := Integer(g_SCWebLlm_ParentHwnd)
    if wantPause {
        g_SCWebLlm_LastBoundsKey := ""
        g_SCWebLlm_ChildHostBoundsCache := Map()
        try ScWebLlm_HideEmbedBackdrop()
        catch as e {
            ScWebLlm_Catch(e)
        }
        for sid, rec in g_SCWebLlm_SiteHosts {
            if !(rec is Map)
                continue
            hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
            if hostHwnd {
                id := "ahk_id " . hostHwnd
                try WinHide(id)
                SearchCenterWebLlm_PositionChildHost(hostHwnd, 0, 0, 0, 0, false, parentHwnd)
            }
            if IsObject(rec["ctrl"]) {
                try rec["ctrl"].IsVisible := false
                catch {
                }
            }
        }
        return true
    }
    if g_SCWebLlm_Visible && parentHwnd && FuncExists("SearchCenterWebLlm_ApplyBounds") {
        try SearchCenterWebLlm_ApplyBounds(parentHwnd)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return true
}

ScWebLlm_UnifiedResolveEmbedViewport(hwnd, &embedLeft, &embedTop, &embedW, &embedH) {
    global g_SCWebLlm_UnifiedEmbedViewport
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    if !(g_SCWebLlm_UnifiedEmbedViewport is Map)
        return false
    vpW := Integer(g_SCWebLlm_UnifiedEmbedViewport.Get("width", 0))
    vpH := Integer(g_SCWebLlm_UnifiedEmbedViewport.Get("height", 0))
    if (vpW < 80 || vpH < 80)
        return false
    if FuncExists("_SCWV_ViewportRectToParentClient") {
        try {
            if _SCWV_ViewportRectToParentClient(g_SCWebLlm_UnifiedEmbedViewport, hwnd, &embedLeft, &embedTop, &embedW, &embedH)
                return true
        } catch {
        }
    }
    embedLeft := Integer(g_SCWebLlm_UnifiedEmbedViewport.Get("left", 0))
    embedTop := Integer(g_SCWebLlm_UnifiedEmbedViewport.Get("top", 0))
    embedW := vpW
    embedH := vpH
    return (embedW > 0 && embedH > 0)
}

ScWebLlm_UnifiedSetEmbedViewport(rawViewport) {
    global g_SCWebLlm_UnifiedEmbedViewport, g_SCWebLlm_LastBoundsKey
    if !(rawViewport is Map)
        return false
    rl := Integer(rawViewport.Get("left", 0))
    rt := Integer(rawViewport.Get("top", 0))
    rw := Integer(rawViewport.Get("width", 0))
    rh := Integer(rawViewport.Get("height", 0))
    if (rw < 80 || rh < 80)
        return false
    prev := (g_SCWebLlm_UnifiedEmbedViewport is Map) ? g_SCWebLlm_UnifiedEmbedViewport : Map()
    if (Integer(prev.Get("left", -1)) = rl && Integer(prev.Get("top", -1)) = rt
        && Integer(prev.Get("width", -1)) = rw && Integer(prev.Get("height", -1)) = rh)
        return true
    g_SCWebLlm_UnifiedEmbedViewport := Map("left", rl, "top", rt, "width", rw, "height", rh)
    g_SCWebLlm_LastBoundsKey := ""
    return true
}

ScWebLlm_UnifiedMultiRectApplyBounds(parentHwnd := 0) {
    global g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd
    global g_SCWebLlm_SiteBoundsSig, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_SiteHosts, g_SCWebLlm_LayoutSiteIds, g_SCWebLlm_OwnerOverlay
    global g_SCWebLlm_UnifiedLayoutPaused
    global g_SCWebLlm_UnifiedLayoutLiveDrag
    if g_SCWebLlm_UnifiedLayoutPaused
        return false
    if ScWebLlm_ShouldSkipEmbedWinOps()
        return false
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : g_SCWebLlm_ParentHwnd
    if !hwnd || !g_SCWebLlm_Visible || !g_SCWebLlm_UnifiedColumnRects.Count
        return false
    g_SCWebLlm_ParentHwnd := hwnd
    SearchCenterWebLlm_LowerMainWebView()
    ScWebLlm_HideEmbedBackdrop()
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    hasEmbedVp := ScWebLlm_UnifiedResolveEmbedViewport(hwnd, &embedLeft, &embedTop, &embedW, &embedH)
    key := "umr:" . (hasEmbedVp ? embedLeft . "x" . embedTop . "x" . embedW . "x" . embedH . ";" : "")
    layoutSet := Map()
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    for sid in g_SCWebLlm_LayoutSiteIds {
        sidNorm := ScWebLlm_NormalizeSiteId(sid)
        if (sidNorm = "" || !g_SCWebLlm_UnifiedColumnRects.Has(sidNorm))
            continue
        rect := g_SCWebLlm_UnifiedColumnRects[sidNorm]
        if !(rect is Map)
            continue
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        converted := false
        if FuncExists("_SCWV_ViewportRectToParentClient") {
            try converted := _SCWV_ViewportRectToParentClient(rect, hwnd, &colL, &colT, &colW, &colH)
            catch {
                converted := false
            }
        }
        if !converted {
            colL := Integer(rect.Get("left", 0))
            colT := Integer(rect.Get("top", 0))
            colW := Integer(rect.Get("width", 0))
            colH := Integer(rect.Get("height", 0))
        }
        key .= sidNorm . ":" . colL . "x" . colT . "x" . colW . "x" . colH . ";"
        layoutSet[sidNorm] := true
        rec := SearchCenterWebLlm_SiteRecord(sidNorm)
        if !(rec is Map)
            continue
        hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
        if !hostHwnd
            hostHwnd := SearchCenterWebLlm_EnsureSiteHost(hwnd, sidNorm)
        if !hostHwnd
            continue
        showCol := (colW >= 80 && colH >= 80)
        inView := showCol && (!hasEmbedVp || ScWebLlm_ColumnIntersectsViewport(colL, colW, embedLeft, embedW))
        if inView {
            liveFlags := g_SCWebLlm_UnifiedLayoutLiveDrag ? 0x0400 : 0
            SearchCenterWebLlm_PositionChildHost(hostHwnd, colL, colT, colW, colH, true, hwnd, liveFlags)
            if hasEmbedVp
                ScWebLlm_ApplyHostViewportClip(hostHwnd, colL, colW, colH, embedLeft, embedW)
            else
                ScWebLlm_ClearHostViewportClip(hostHwnd)
        } else {
            ScWebLlm_ClearHostViewportClip(hostHwnd)
            SearchCenterWebLlm_PositionChildHost(hostHwnd, 0, 0, 0, 0, false, hwnd)
        }
        boundsSig := colW . "x" . colH
        g_SCWebLlm_SiteBoundsSig[sidNorm] := boundsSig
        if IsObject(rec["ctrl"]) && hostHwnd && inView {
            try {
                WinGetClientPos(, , &hw, &hh, hostHwnd)
                if (hw > 0 && hh > 0) {
                    rc := WebView2.RECT()
                    rc.left := 0
                    rc.top := 0
                    rc.right := hw
                    rc.bottom := hh
                    rec["ctrl"].Bounds := rc
                    rec["ctrl"].NotifyParentWindowPositionChanged()
                }
            } catch as e {
                ScWebLlm_Catch(e)
            }
            try rec["ctrl"].IsVisible := true
            catch {
            }
            if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
                try WebView2_NotifyShown(rec["wv2"])
                catch {
                }
            }
        } else if IsObject(rec["ctrl"]) && hostHwnd && !inView {
            try rec["ctrl"].IsVisible := false
            catch {
            }
            ScWebLlm_UnifiedNotifySiteMemoryLevel(sidNorm, false)
        }
    }
    for sid, rec in g_SCWebLlm_SiteHosts {
        sidNorm := ScWebLlm_NormalizeSiteId(sid)
        if !(rec is Map) || layoutSet.Has(sidNorm)
            continue
        if rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_PositionChildHost(rec["hostHwnd"], 0, 0, 0, 0, false, hwnd)
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
        ScWebLlm_UnifiedNotifySiteMemoryLevel(sidNorm, false)
    }
    if (key = g_SCWebLlm_LastBoundsKey) {
        try SearchCenterWebLlm_EnsureMissingSites(false, hwnd)
        catch as e {
            ScWebLlm_Catch(e)
        }
        ScWebLlm_EnsureUnifiedMultiHostStack(activeNorm)
        return true
    }
    g_SCWebLlm_LastBoundsKey := key
    try SearchCenterWebLlm_EnsureMissingSites(false, hwnd)
    catch as e {
        ScWebLlm_Catch(e)
    }
    ScWebLlm_EnsureUnifiedMultiHostStack(activeNorm)
    SearchCenterWebLlm_SyncActiveGlobals()
    try ScWebLlm_UnifiedTrimExcessSiteHosts(Max(12, ScWebLlm_UnifiedMaxActiveAiEmbeds() + 4))
    catch as e {
        ScWebLlm_Catch(e)
    }
    return true
}

ScWebLlm_EnsureUnifiedMultiHostStack(activeSiteId := "") {
    global g_SCWebLlm_LayoutSiteIds, g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_MainWebViewLowered, g_SCWebLlm_OwnerOverlay, g_SCWebLlm_Visible
    global g_SCWebLlm_LastRaisedHostHwnd
    if ScWebLlm_ShouldSkipEmbedWinOps()
        return
    if !ScWebLlm_ShouldShowWebEmbed() || !g_SCWebLlm_Visible || ScWebLlm_IsRailDragging()
        return
    if !g_SCWebLlm_OwnerOverlay && !g_SCWebLlm_MainWebViewLowered
        SearchCenterWebLlm_LowerMainWebView()
    g_SCWebLlm_LastRaisedHostHwnd := 0
    ordered := []
    for sid in g_SCWebLlm_LayoutSiteIds {
        sidNorm := ScWebLlm_NormalizeSiteId(sid)
        if (sidNorm = "" || !g_SCWebLlm_UnifiedColumnRects.Has(sidNorm))
            continue
        rect := g_SCWebLlm_UnifiedColumnRects[sidNorm]
        colLeft := (rect is Map) ? Integer(rect.Get("left", 0)) : 0
        ordered.Push(Map("sid", sidNorm, "left", colLeft))
    }
    if ordered.Length > 1 {
        try ordered.Sort((a, b) => Integer(a["left"]) - Integer(b["left"]))
        catch {
        }
    }
    activeNorm := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (activeNorm = "")
        activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if ScWebLlm_IsUnifiedWorkbenchHost() {
        for item in ordered {
            sidNorm := String(item["sid"])
            rec := SearchCenterWebLlm_SiteRecord(sidNorm)
            if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
                SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
        }
        return
    }
    for item in ordered {
        sidNorm := String(item["sid"])
        rec := SearchCenterWebLlm_SiteRecord(sidNorm)
        if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
    }
    if (activeNorm != "") {
        rec := SearchCenterWebLlm_SiteRecord(activeNorm)
        if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
    }
}

SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb(rawColumns, maxActive := 0, focusSiteId := "", embedViewport := 0, liveOnly := false) {
    global g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_LayoutSiteIds
    global SearchCenterSelectedEngines, g_SCWebLlm_BroadcastSynced, g_SCWebLlm_ContentRect, g_SCWebLlm_ContentRectReady
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_BootstrapWaitCount, g_SCWebLlm_Visible
    global g_SCWebLlm_UnifiedLayoutBootstrapScheduled, g_SCWebLlm_UnifiedLayoutNudgeCount, g_SCWebLlm_UnifiedEmbedViewport
    if !(rawColumns is Array) || !rawColumns.Length
        return false
    if (embedViewport is Map)
        ScWebLlm_UnifiedSetEmbedViewport(embedViewport)
    limit := Integer(maxActive)
    if (limit < 1)
        limit := ScWebLlm_UnifiedMaxActiveAiEmbeds()
    if (limit > 8)
        limit := 8
    rects := Map()
    siteIds := []
    unionL := 999999
    unionT := 999999
    unionR := 0
    unionB := 0
    for item in rawColumns {
        if !(item is Map) || siteIds.Length >= limit
            continue
        sidRaw := item.Has("siteId") ? String(item["siteId"]) : (item.Has("id") ? String(item["id"]) : "")
        sidNorm := ScWebLlm_NormalizeSiteId(sidRaw)
        if (sidNorm = "" || !ScWebLlm_IsSiteEnabled(sidNorm))
            continue
        dup := false
        for existing in siteIds {
            if (existing = sidNorm) {
                dup := true
                break
            }
        }
        if dup
            continue
        rectRaw := item.Has("rect") ? item["rect"] : item
        if !(rectRaw is Map)
            continue
        rw := Max(0, Integer(rectRaw.Get("width", 0)))
        rh := Max(0, Integer(rectRaw.Get("height", 0)))
        if (rw < 80 || rh < 80)
            continue
        rl := Integer(rectRaw.Get("left", 0))
        rt := Integer(rectRaw.Get("top", 0))
        rects[sidNorm] := Map(
            "left", rl,
            "top", rt,
            "width", rw,
            "height", rh
        )
        siteIds.Push(sidNorm)
        if (rl < unionL)
            unionL := rl
        if (rt < unionT)
            unionT := rt
        if (rl + rw > unionR)
            unionR := rl + rw
        if (rt + rh > unionB)
            unionB := rt + rh
    }
    if !siteIds.Length {
        UnifiedWb_Trace("apply_columns", false, Map("reason", "no_sites"))
        return false
    }
    g_SCWebLlm_UnifiedColumnRects := rects
    g_SCWebLlm_UnifiedMultiRectActive := true
    g_SCWebLlm_LayoutSiteIds := siteIds.Clone()
    g_SCWebLlm_UnifiedLayoutBootstrapScheduled := false
    g_SCWebLlm_UnifiedLayoutNudgeCount := 0
    SearchCenterSelectedEngines := siteIds.Clone()
    g_SCWebLlm_BroadcastSynced := true
    if (unionL = 999999)
        unionL := 0
    if (unionT = 999999)
        unionT := 0
    g_SCWebLlm_ContentRect := Map(
        "left", unionL,
        "top", unionT,
        "width", Max(200, unionR - unionL),
        "height", Max(140, unionB - unionT)
    )
    g_SCWebLlm_ContentRectReady := true
    g_SCWebLlm_BootstrapWaitCount := 0
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_Visible := true
    if !liveOnly {
        focusNorm := ScWebLlm_NormalizeSiteId(focusSiteId)
        focusFound := false
        if (focusNorm != "") {
            for sid in siteIds {
                if (sid = focusNorm) {
                    focusFound := true
                    break
                }
            }
        }
        if focusFound
            g_SCWebLlm_ActiveSiteId := focusNorm
        else
            g_SCWebLlm_ActiveSiteId := siteIds[1]
    }
    h := ScWebLlm_GetEmbedParentHwnd()
    if liveOnly {
        if h {
            global g_SCWebLlm_UnifiedLayoutLiveDrag
            g_SCWebLlm_UnifiedLayoutLiveDrag := true
            try ScWebLlm_UnifiedMultiRectApplyBounds(h)
            catch as e {
                ScWebLlm_Catch(e)
            }
            g_SCWebLlm_UnifiedLayoutLiveDrag := false
        }
        return true
    }
    if h && !ScWebLlm_IsUnifiedLayoutPaused() {
        SearchCenterWebLlm_LowerMainWebView()
        try SearchCenterWebLlm_ApplyBounds(h)
        catch as e {
            ScWebLlm_Catch(e)
        }
        try SearchCenterWebLlm_EnsureMissingSites(false, h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if !ScWebLlm_IsUnifiedLayoutPaused() {
        try ScWebLlm_UnifiedTrimExcessSiteHosts(Max(12, limit + 4))
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if FuncExists("UnifiedWb_Trace")
        UnifiedWb_Trace("apply_columns", true, Map("sites", siteIds.Length, "focus", g_SCWebLlm_ActiveSiteId))
    return true
}

SearchCenterWebLlm_IsEmbedChildHwnd(hwnd) {
    global g_SCWebLlm_SiteHosts
    h := Integer(hwnd)
    if (h <= 0)
        return false
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map) || !rec.Has("hostHwnd")
            continue
        host := 0
        try host := Integer(rec["hostHwnd"])
        catch {
            continue
        }
        if !host
            continue
        if (h = host)
            return true
        hw := h
        Loop 12 {
            np := 0
            try np := DllCall("GetParent", "Ptr", hw, "Ptr")
            catch {
                break
            }
            if !np
                break
            if (np = host)
                return true
            hw := np
        }
    }
    return false
}

ScWebLlm_Trace(action, ok := true, meta := 0) {
    act := String(action)
    metaCopy := Map()
    if (meta is Map) {
        for k, v in meta
            metaCopy[String(k)] := v
    }
    try SetTimer(ScWebLlm_TraceDeferred.Bind(act, !!ok, metaCopy), -1)
    catch {
    }
}

ScWebLlm_TraceDeferred(action, ok, meta, *) {
    static tracing := false
    if tracing
        return
    tracing := true
    try {
        fn := "Nmer_Telemetry_Record"
        if FuncExists(fn) {
            try {
                (%fn%)("web_llm", action, !!ok, meta is Map ? meta : Map())
            } catch {
            }
        }
        try {
            line := "[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "][" . String(action) . "] ok=" . (ok ? "1" : "0")
            if (meta is Map) {
                for k, v in meta
                    line .= " " . String(k) . "=" . String(v)
            }
            dir := A_ScriptDir . "\Cache\debug"
            if !DirExist(dir)
                DirCreate(dir)
            path := dir . "\sc_web_llm_runtime.log"
            f := FileOpen(path, "a", "UTF-8")
            if IsObject(f) {
                f.Write(line . "`n")
                f.Close()
            }
        } catch {
        }
    } finally {
        tracing := false
    }
}

ScWebLlm_ReadDebugLogTail(fileName, maxLines := 48, filterNeedle := "") {
    path := A_ScriptDir . "\Cache\debug\" . fileName
    if FuncExists("Nmer_DebugPath")
        path := Nmer_DebugPath(fileName)
    if !FileExist(path)
        return ""
    try {
        lines := []
        needle := Trim(String(filterNeedle))
        for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
            t := Trim(line)
            if (t = "")
                continue
            if (needle != "" && !InStr(t, needle))
                continue
            lines.Push(t)
        }
        if !lines.Length
            return "(无匹配行)"
        start := lines.Length > maxLines ? (lines.Length - maxLines + 1) : 1
        out := ""
        Loop (lines.Length - start + 1) {
            i := start + A_Index - 1
            out .= (out = "" ? "" : "`n") . lines[i]
        }
        return out
    } catch as e {
        return "(读取失败: " . e.Message . ")"
    }
}

SearchCenterWebLlm_BuildDebugSnapshot(clientMeta := 0) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ContentRectReady, g_SCWebLlm_ContentRect, g_SCWebLlm_EmbedBootstrapped
    global g_SCWebLlm_EmbedRequested, g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight
    global g_SCWebLlm_BootstrapWaitCount, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_SiteHosts
    global g_SCWV_UiMode, g_SCWV_Ctrl, g_SCWV_Gui, SearchCenterSelectedEngines, SearchCenterFilterType

    cat := ""
    try cat := StrLower(Trim(String(GetSearchCenterCurrentCategoryKey())))
    catch {
        cat := ""
    }
    uiMode := IsSet(g_SCWV_UiMode) ? StrLower(Trim(String(g_SCWV_UiMode))) : ""
    layoutIds := SearchCenterWebLlm_ListLayoutSiteIds()
    sel := []
    if IsObject(SearchCenterSelectedEngines) {
        for eng in SearchCenterSelectedEngines
            sel.Push(String(eng))
    }
    rect := (g_SCWebLlm_ContentRect is Map) ? g_SCWebLlm_ContentRect : Map()
    sites := []
    for sid in layoutIds {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        site := ScWebLlm_FindSite(sid)
        row := Map(
            "id", sid,
            "label", site is Map ? String(site.Get("label", sid)) : sid,
            "enabled", ScWebLlm_IsSiteEnabled(sid),
            "ready", rec is Map ? !!rec.Get("ready", false) : false,
            "createInFlight", rec is Map ? !!rec.Get("createInFlight", false) : false,
            "hostHwnd", rec is Map ? Integer(rec.Get("hostHwnd", 0)) : 0,
            "hasWv2", rec is Map ? !!IsObject(rec.Get("wv2", 0)) : false
        )
        if (rec is Map) {
            started := Integer(rec.Get("createStarted", 0))
            if (started > 0)
                row["createAgeMs"] := A_TickCount - started
            if rec.Has("lastNavError")
                row["lastNavError"] := String(rec["lastNavError"])
            if rec.Has("lastUrl")
                row["lastUrl"] := String(rec["lastUrl"])
        }
        sites.Push(row)
    }
    issues := []
    isUnified := ScWebLlm_IsUnifiedWorkbenchHost()
    if !isUnified {
        if (uiMode != "web")
            issues.Push(Map("level", "warn", "code", "mode", "msg", "UI 模式不是 web，内嵌 AI 不会显示"))
        if (cat != "ai")
            issues.Push(Map("level", "warn", "code", "category", "msg", "当前分类不是 ai，需选「大模型/AI」分类"))
    }
    if !g_SCWebLlm_ContentRectReady
        issues.Push(Map("level", "error", "code", "rect", "msg", "内容区矩形未就绪（宽≥160 高≥80），WebView 无法创建"))
    if !(g_SCWebLlm_EmbedRequested || g_SCWebLlm_Visible)
        issues.Push(Map("level", "warn", "code", "embed_flag", "msg", "尚未收到内嵌请求（EmbedRequested/Visible 均为 false）"))
    if (g_SCWebLlm_BootstrapWaitCount >= 12)
        issues.Push(Map("level", "error", "code", "bootstrap_wait", "msg", "Bootstrap 等待超时次数=" . g_SCWebLlm_BootstrapWaitCount))
    if isUnified {
        global g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_OwnerOverlay
        global g_SCWebLlm_UnifiedHostActive, g_SCWebLlm_LayoutSiteIds, g_SCWebLlm_MainWebViewLowered
        if !g_SCWebLlm_UnifiedHostActive
            issues.Push(Map("level", "error", "code", "uwb_host", "msg", "统一工作台宿主未绑定（UnifiedHostActive=false）"))
        if !g_SCWebLlm_UnifiedMultiRectActive
            issues.Push(Map("level", "error", "code", "uwb_layout", "msg", "多列布局未激活：页面尚未发送 webLlmBootstrap(aiColumns)"))
        else if !g_SCWebLlm_UnifiedColumnRects.Count
            issues.Push(Map("level", "error", "code", "uwb_rects", "msg", "UnifiedColumnRects 为空"))
        if g_SCWebLlm_OwnerOverlay
            issues.Push(Map("level", "warn", "code", "uwb_overlay", "msg", "OwnerOverlay 仍为 true，可能导致 AI 窗不可见"))
        if !g_SCWebLlm_MainWebViewLowered
            issues.Push(Map("level", "warn", "code", "uwb_zorder", "msg", "主 WebView 未 Lower，AI 子窗可能被 HTML 层遮挡"))
        if !ScWebLlm_UnifiedEmbedBootstrapReady()
            issues.Push(Map("level", "error", "code", "uwb_wait_layout", "msg", "LayoutSiteIds 未就绪（unified_wait_layout）"))
    }
    for row in sites {
        sid := String(row["id"])
        if !row["enabled"]
            issues.Push(Map("level", "error", "code", "site_disabled", "msg", "站点 " . sid . " 在 catalog 中未启用"))
        else if !row["ready"] && !row["createInFlight"]
            issues.Push(Map("level", "error", "code", "site_missing", "msg", "站点 " . sid . " 未创建 WebView（ready=0 且未在创建中）"))
        else if row["createInFlight"] && row.Has("createAgeMs") && Integer(row["createAgeMs"]) > 20000
            issues.Push(Map("level", "error", "code", "site_stuck", "msg", "站点 " . sid . " 创建已超过 20s，可能卡住"))
    }
    if (clientMeta is Map) {
        jsSites := clientMeta.Has("broadcastSites") ? clientMeta["broadcastSites"] : []
        if (jsSites is Array) {
            for jsSid in jsSites {
                v := Trim(String(jsSid))
                if (v = "")
                    continue
                found := false
                for s in sel {
                    if (StrLower(s) = StrLower(v)) {
                        found := true
                        break
                    }
                }
                if !found
                    issues.Push(Map("level", "error", "code", "sync_mismatch", "msg", "页面已选 " . v . " 但宿主 selectedEngines 未同步"))
            }
            if (clientMeta.Has("hostRectNull") && clientMeta["hostRectNull"])
                issues.Push(Map("level", "error", "code", "js_rect", "msg", "页面测不到内嵌视口矩形（viewport 过小或 workspace 隐藏）"))
        }
        if isUnified && (clientMeta is Map) {
            if clientMeta.Has("canAutoBootstrap") && !clientMeta["canAutoBootstrap"]
                issues.Push(Map("level", "error", "code", "uwb_js_boot", "msg", "页面 canAutoBootstrap=false（hostLive/hostArmed 或列为空）"))
            if clientMeta.Has("aiColumnCount") && Integer(clientMeta["aiColumnCount"]) < 1
                issues.Push(Map("level", "error", "code", "uwb_js_cols", "msg", "页面未选出 AI 嵌入列"))
            if clientMeta.Has("measureFailed") && clientMeta["measureFailed"]
                issues.Push(Map("level", "error", "code", "uwb_js_measure", "msg", "页面列矩形测量失败（见 uwb 日志）"))
            if clientMeta.Has("syncRetries") && Integer(clientMeta["syncRetries"]) >= 12
                issues.Push(Map("level", "error", "code", "uwb_js_retry", "msg", "syncAllAiEmbeds 重试过多，可能 DOM 未就绪"))
        }
    }
    logDir := A_ScriptDir . "\Cache\debug"
    if FuncExists("Nmer_DebugDir")
        logDir := Nmer_DebugDir()
    snap := Map(
        "ts", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
        "uiMode", uiMode,
        "category", cat,
        "filterType", String(SearchCenterFilterType),
        "selectedEngines", sel,
        "layoutSiteIds", layoutIds,
        "activeSiteId", String(g_SCWebLlm_ActiveSiteId),
        "flags", Map(
            "visible", !!g_SCWebLlm_Visible,
            "embedRequested", !!g_SCWebLlm_EmbedRequested,
            "contentRectReady", !!g_SCWebLlm_ContentRectReady,
            "embedBootstrapped", !!g_SCWebLlm_EmbedBootstrapped,
            "bootstrapScheduled", !!g_SCWebLlm_BootstrapScheduled,
            "bootstrapInFlight", !!g_SCWebLlm_BootstrapInFlight,
            "bootstrapWaitCount", Integer(g_SCWebLlm_BootstrapWaitCount),
            "canBootstrap", !!SearchCenterWebLlm_CanBootstrapEmbed(),
            "scwvReady", IsObject(g_SCWV_Ctrl),
            "parentHwnd", Integer(g_SCWebLlm_ParentHwnd),
            "hostGuiHwnd", (IsObject(g_SCWV_Gui) && g_SCWV_Gui) ? Integer(g_SCWV_Gui.Hwnd) : 0,
            "mainWebViewLowered", !!g_SCWebLlm_MainWebViewLowered
        ),
        "contentRect", Map(
            "left", Integer(rect.Get("left", 0)),
            "top", Integer(rect.Get("top", 0)),
            "width", Integer(rect.Get("width", 0)),
            "height", Integer(rect.Get("height", 0)),
            "dpr", rect.Has("dpr") ? Float(rect["dpr"]) : 0
        ),
        "sites", sites,
        "issues", issues,
        "logDir", logDir,
        "logs", Map(
            "webLlm", ScWebLlm_ReadDebugLogTail("sc_web_llm_runtime.log", 40),
            "scwv", ScWebLlm_ReadDebugLogTail("scwv_trace.log", 32, "web"),
            "wv2", ScWebLlm_ReadDebugLogTail("wv2_shared_env.log", 24, "web_llm"),
            "uwb", ScWebLlm_ReadDebugLogTail("unified_workbench_debug.log", 48)
        )
    )
    if isUnified {
        global g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_UnifiedColumnRects, g_SCWebLlm_OwnerOverlay
        global g_SCWebLlm_UnifiedHostActive, g_SCWebLlm_LayoutSiteIds
        uLayout := []
        if IsObject(g_SCWebLlm_LayoutSiteIds) {
            for sid in g_SCWebLlm_LayoutSiteIds
                uLayout.Push(String(sid))
        }
        uRects := []
        for sid, rect in g_SCWebLlm_UnifiedColumnRects {
            if !(rect is Map)
                continue
            uRects.Push(Map(
                "siteId", String(sid),
                "left", Integer(rect.Get("left", 0)),
                "top", Integer(rect.Get("top", 0)),
                "width", Integer(rect.Get("width", 0)),
                "height", Integer(rect.Get("height", 0))
            ))
        }
        snap["unified"] := Map(
            "hostActive", !!g_SCWebLlm_UnifiedHostActive,
            "multiRectActive", !!g_SCWebLlm_UnifiedMultiRectActive,
            "ownerOverlay", !!g_SCWebLlm_OwnerOverlay,
            "layoutReady", ScWebLlm_UnifiedEmbedBootstrapReady(),
            "layoutSiteIds", uLayout,
            "columnRects", uRects
        )
    }
    return snap
}

ScWebLlm_StatePath() {
    if FuncExists("Nmer_ScWebLlmStatePath")
        return Nmer_ScWebLlmStatePath()
    return A_ScriptDir . "\Data\runtime\app\search_center_web_llm_state.json"
}

SearchCenterWebLlm_LoadState() {
    global g_SCWebLlm_StateCache
    path := ScWebLlm_StatePath()
    st := Map("activeSiteId", ScWebLlm_DefaultSiteId(), "sites", Map())
    if !FileExist(path)
        return st
    try {
        if FuncExists("Jxon_Load") {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                loaded := Jxon_Load(raw)
                if (loaded is Map) {
                    if loaded.Has("activeSiteId")
                        st["activeSiteId"] := ScWebLlm_NormalizeSiteId(loaded["activeSiteId"])
                    if loaded.Has("sites") && (loaded["sites"] is Map)
                        st["sites"] := loaded["sites"]
                }
            }
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
    if (st["activeSiteId"] = "")
        st["activeSiteId"] := ScWebLlm_DefaultSiteId()
    g_SCWebLlm_StateCache := st
    return st
}

SearchCenterWebLlm_SaveState() {
    global g_SCWebLlm_StateCache, g_SCWebLlm_ActiveSiteId
    SearchCenterWebLlm_SyncActiveGlobals()
    global g_SCWebLlm_WV2
    st := (g_SCWebLlm_StateCache is Map) ? g_SCWebLlm_StateCache : Map()
    if !(st.Has("sites") && (st["sites"] is Map))
        st["sites"] := Map()
    sites := st["sites"]
    sid := Trim(String(g_SCWebLlm_ActiveSiteId))
    if (sid != "" && IsObject(g_SCWebLlm_WV2)) {
        try {
            url := Trim(String(g_SCWebLlm_WV2.Source))
            if (url != "")
                sites[sid] := Map("lastUrl", url)
        } catch {
        }
    }
    if (sid != "")
        st["activeSiteId"] := sid
    st["sites"] := sites
    g_SCWebLlm_StateCache := st
    path := ScWebLlm_StatePath()
    dir := ""
    if RegExMatch(path, "^(.*)\\[^\\]+$", &m)
        dir := m[1]
    if (dir != "" && !DirExist(dir))
        try DirCreate(dir)
    try {
        if FuncExists("Jxon_Dump") {
            json := Jxon_Dump(st)
            try FileDelete(path)
            FileAppend(json, path, "UTF-8")
            return true
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
    return false
}

SearchCenterWebLlm_SiteLastUrl(siteId) {
    st := SearchCenterWebLlm_LoadState()
    sites := st.Has("sites") && (st["sites"] is Map) ? st["sites"] : Map()
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "" || !sites.Has(sid))
        return ""
    row := sites[sid]
    if (row is Map) && row.Has("lastUrl") {
        u := Trim(String(row["lastUrl"]))
        if !ScWebLlm_IsBlankEmbedUrl(u)
            return u
    }
    return ""
}

SearchCenterWebLlm_CreateChildHostGui(ownerHwnd, bgColor := "F8FAFC") {
    owner := Integer(ownerHwnd)
    if !owner
        return 0
    global g_SCWebLlm_OwnerOverlay
    try {
        if g_SCWebLlm_OwnerOverlay {
            g := Gui("+Owner" . owner . " -Caption +ToolWindow -DPIScale", "SCWebLlmEmbed")
            g.BackColor := bgColor
            g.Show("Hide x-32000 y-32000 w390 h700")
            return Map("gui", g, "hwnd", g.Hwnd)
        }
        g := Gui("-Caption -SysMenu +E0x08000000 -DPIScale", "SCWebLlmEmbed")
        g.BackColor := bgColor
        g.Show("Hide w400 h400")
        hwnd := g.Hwnd
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")
        style := (style | 0x40000000 | 0x10000000) & ~0x80000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", style, "Ptr")
        if !DllCall("SetParent", "Ptr", hwnd, "Ptr", owner, "Ptr") {
            try g.Destroy()
            return 0
        }
        return Map("gui", g, "hwnd", hwnd)
    } catch as e {
        ScWebLlm_Catch(e)
        return 0
    }
}

SearchCenterWebLlm_PositionChildHost(hostHwnd, x, y, w, h, show := true, parentHwnd := 0, extraFlags := 0) {
    if !hostHwnd || ScWebLlm_ShouldSkipEmbedWinOps() || !ScWebLlm_IsUsableChildHwnd(hostHwnd)
        return
    global g_SCWebLlm_OwnerOverlay, g_SCWebLlm_ParentHwnd, g_SCWebLlm_ChildHostBoundsCache
    sx := Integer(x)
    sy := Integer(y)
    sw := Integer(w)
    sh := Integer(h)
    vis := (show && sw > 0 && sh > 0) ? 1 : 0
    unifiedHost := ScWebLlm_IsUnifiedWorkbenchHost()
    if (vis && ScWebLlm_IsUnifiedLayoutPaused())
        return
    boundsKey := sx . "x" . sy . "x" . sw . "x" . sh . "x" . vis . "x" . (unifiedHost ? 1 : 0)
    if g_SCWebLlm_ChildHostBoundsCache.Has(hostHwnd) && (g_SCWebLlm_ChildHostBoundsCache[hostHwnd] = boundsKey)
        return
    g_SCWebLlm_ChildHostBoundsCache[hostHwnd] := boundsKey
    id := "ahk_id " . hostHwnd
    if g_SCWebLlm_OwnerOverlay {
        sx := Integer(x)
        sy := Integer(y)
        ph := Integer(parentHwnd) ? Integer(parentHwnd) : Integer(g_SCWebLlm_ParentHwnd)
        if ph {
            pt := Buffer(8, 0)
            NumPut("Int", sx, pt, 0)
            NumPut("Int", sy, pt, 4)
            try {
                if DllCall("ClientToScreen", "Ptr", ph, "Ptr", pt) {
                    sx := NumGet(pt, 0, "Int")
                    sy := NumGet(pt, 4, "Int")
                }
            } catch as e {
                ScWebLlm_Catch(e)
            }
        }
        if (show && w > 0 && h > 0) {
            try WinMove(sx, sy, w, h, id)
            try WinShow(id)
            try DllCall("BringWindowToTop", "Ptr", hostHwnd)
            catch as e {
                ScWebLlm_Catch(e)
            }
        } else {
            try WinHide(id)
        }
        return
    }
    flags := 0x0010 | Integer(extraFlags)
    if !unifiedHost
        flags |= 0x0004
    if (show && w > 0 && h > 0)
        flags |= 0x0040
    else {
        flags |= 0x0080
        w := 0
        h := 0
    }
    if unifiedHost && !vis {
        try WinHide(id)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
    catch as e {
        ScWebLlm_Catch(e)
    }
    if unifiedHost && vis {
        try WinShow(id)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

SearchCenterWebLlm_LowerMainWebView(retryPass := 0) {
    global g_SCWebLlm_MainWebViewLowered, g_SCWV_Ctrl, g_SCWebLlm_ParentHwnd
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if g_SCWebLlm_MainWebViewLowered
        return
    if ScWebLlm_IsUnifiedWorkbenchHost() {
        ; 统一工作台壳页 WebView 必须保持可见以渲染 CLI 列；AI 子窗叠在对应列区域即可。
        g_SCWebLlm_MainWebViewLowered := true
        return
    }
    if !IsObject(g_SCWV_Ctrl)
        return
    mainHwnd := 0
    try mainHwnd := g_SCWV_Ctrl.ParentWindow
    catch {
    }
    if !mainHwnd {
        if (retryPass < 16)
            SetTimer(SearchCenterWebLlm_LowerMainWebView.Bind(retryPass + 1), -Min(80 + retryPass * 60, 500))
        return
    }
    try DllCall("SetWindowPos", "Ptr", mainHwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
        return
    }
    g_SCWebLlm_MainWebViewLowered := true
}

SearchCenterWebLlm_RestoreMainWebView() {
    global g_SCWebLlm_MainWebViewLowered, g_SCWV_Ctrl
    if !g_SCWebLlm_MainWebViewLowered
        return
    if !IsObject(g_SCWV_Ctrl)
        return
    mainHwnd := 0
    try mainHwnd := g_SCWV_Ctrl.ParentWindow
    catch {
    }
    if mainHwnd {
        try DllCall("SetWindowPos", "Ptr", mainHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    g_SCWebLlm_MainWebViewLowered := false
}

SearchCenterWebLlm_LowerChildHost(hostHwnd) {
    if !hostHwnd || ScWebLlm_ShouldSkipEmbedWinOps() || !ScWebLlm_IsUsableChildHwnd(hostHwnd)
        return
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_RaiseChildHost(hostHwnd) {
    if !hostHwnd || ScWebLlm_ShouldSkipEmbedWinOps() || !ScWebLlm_IsUsableChildHwnd(hostHwnd)
        return
    if ScWebLlm_IsUnifiedLayoutPaused()
        return
    global g_SCWebLlm_OwnerOverlay, g_SCWebLlm_LastRaisedHostHwnd
    if (Integer(hostHwnd) = Integer(g_SCWebLlm_LastRaisedHostHwnd))
        return
    g_SCWebLlm_LastRaisedHostHwnd := hostHwnd
    if g_SCWebLlm_OwnerOverlay {
        id := "ahk_id " . hostHwnd
        try WinSetAlwaysOnTop false, id
        catch {
        }
        try WinShow(id)
        catch as e {
            ScWebLlm_Catch(e)
        }
        try DllCall("BringWindowToTop", "Ptr", hostHwnd)
        catch as e {
            ScWebLlm_Catch(e)
        }
        return
    }
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_EnsureEmbedHostStack(activeSiteId := "") {
    global g_SCWebLlm_OwnerOverlay, g_SCWebLlm_Visible, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_MainWebViewLowered
    if ScWebLlm_ShouldSkipEmbedWinOps()
        return
    if !ScWebLlm_ShouldShowWebEmbed() || !g_SCWebLlm_Visible || ScWebLlm_IsRailDragging()
        return
    activeNorm := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (activeNorm = "")
        activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if !g_SCWebLlm_OwnerOverlay && !g_SCWebLlm_MainWebViewLowered
        SearchCenterWebLlm_LowerMainWebView()
    SearchCenterWebLlm_RaiseSiteHosts(activeNorm)
}

SearchCenterWebLlm_RaiseSiteHosts(activeSiteId := "") {
    active := ScWebLlm_NormalizeSiteId(activeSiteId)
    if (active = "")
        return
    rec := SearchCenterWebLlm_SiteRecord(active)
    if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
        SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
}

ScWebLlm_BeginEmbedFocusGuard(ms := 15000) {
    global g_SCWebLlm_EmbedFocusGuardUntil
    guardUntil := A_TickCount + Max(4000, Integer(ms))
    if (guardUntil > g_SCWebLlm_EmbedFocusGuardUntil)
        g_SCWebLlm_EmbedFocusGuardUntil := guardUntil
}

ScWebLlm_EndEmbedFocusGuard() {
    global g_SCWebLlm_EmbedFocusGuardUntil
    g_SCWebLlm_EmbedFocusGuardUntil := 0
}

ScWebLlm_IsEmbedFocusGuarded() {
    global g_SCWebLlm_EmbedFocusGuardUntil, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapScheduled
    if (g_SCWebLlm_EmbedFocusGuardUntil > A_TickCount)
        return true
    if (g_SCWebLlm_BootstrapInFlight || g_SCWebLlm_BootstrapScheduled)
        return true
    return false
}

ScWebLlm_AllowEmbedFocusSteal() {
    if ScWebLlm_IsEmbedFocusGuarded()
        return false
    fn := "SCWV_IsSearchCenterForegroundOrChild"
    if FuncExists(fn) {
        try {
            if !(%fn%)()
                return false
        } catch {
            return false
        }
    }
    return true
}

ScWebLlm_GetRasterScale() {
    global g_SCWebLlm_ContentRect, g_SCWV_Ctrl
    if (g_SCWebLlm_ContentRect is Map) && g_SCWebLlm_ContentRect.Has("dpr") {
        dpr := Float(g_SCWebLlm_ContentRect["dpr"])
        if (dpr > 0.1 && dpr < 10)
            return dpr
    }
    if IsObject(g_SCWV_Ctrl) {
        try {
            sc := g_SCWV_Ctrl.RasterizationScale
            if (sc > 0.1 && sc < 10)
                return sc
        } catch {
        }
    }
    if FuncExists("_SCWV_WebViewRasterScale") {
        try return _SCWV_WebViewRasterScale()
        catch {
        }
    }
    return 1.0
}

ScWebLlm_CssToPhysical(cssPx) {
    return Max(0, Round(Float(cssPx) * ScWebLlm_GetRasterScale()))
}

ScWebLlm_PhysicalToCss(physPx) {
    sc := ScWebLlm_GetRasterScale()
    if (sc < 0.01)
        return Max(0, Integer(physPx))
    return Max(0, Round(Float(physPx) / sc))
}

ScWebLlm_PhysicalDeltaToCss(physPx) {
    sc := ScWebLlm_GetRasterScale()
    if (sc < 0.01)
        return Round(Float(physPx))
    return Round(Float(physPx) / sc)
}

SearchCenterWebLlm_EnsureSiteHost(parentHwnd, siteId) {
    global g_SCWebLlm_ParentHwnd
    sid := ScWebLlm_NormalizeSiteId(siteId)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map)
        return 0
    ph := ScWebLlm_GetEmbedParentHwnd()
    if !ph
        ph := Integer(parentHwnd)
    if !ph
        return 0
    g_SCWebLlm_ParentHwnd := ph
    if rec.Has("hostHwnd") && rec["hostHwnd"] {
        global g_SCWebLlm_OwnerOverlay
        if g_SCWebLlm_OwnerOverlay {
            if (rec.Has("ownerHwnd") && rec["ownerHwnd"] = ph) {
                if IsObject(rec["hostGui"]) {
                    try rec["hostGui"].BackColor := "0b1220"
                    catch {
                    }
                }
                return rec["hostHwnd"]
            }
        } else {
            try {
                if (DllCall("GetParent", "Ptr", rec["hostHwnd"], "Ptr") = ph) {
                    if IsObject(rec["hostGui"]) {
                        try rec["hostGui"].BackColor := "0b1220"
                        catch {
                        }
                    }
                    return rec["hostHwnd"]
                }
            } catch {
            }
        }
    }
    SearchCenterWebLlm_DisposeSiteController(sid)
    if IsObject(rec["hostGui"]) {
        try rec["hostGui"].Destroy()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    created := SearchCenterWebLlm_CreateChildHostGui(ph, "0b1220")
    if !(created is Map) || !created.Has("hwnd") || !created["hwnd"]
        return 0
    rec["hostGui"] := created["gui"]
    rec["hostHwnd"] := created["hwnd"]
    rec["ownerHwnd"] := ph
    return rec["hostHwnd"]
}

SearchCenterWebLlm_EnsureContentHost(parentHwnd) {
    global g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    return SearchCenterWebLlm_EnsureSiteHost(parentHwnd, sid)
}

SearchCenterWebLlm_HostAlive() {
    global g_SCWebLlm_ParentHwnd
    return WebView2_IsUsableHwnd(g_SCWebLlm_ParentHwnd)
}

SearchCenterWebLlm_ControllerAlive() {
    global g_SCWebLlm_ActiveSiteId
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map)
        return false
    return IsObject(rec["ctrl"]) && IsObject(rec["wv2"]) && SearchCenterWebLlm_HostAlive()
}

SearchCenterWebLlm_DisposeSiteController(siteId, preserveCreateInFlight := false) {
    rec := SearchCenterWebLlm_SiteRecord(siteId)
    if !(rec is Map)
        return
    if IsObject(rec["wv2"]) && rec["tokenNavCompleted"] {
        try rec["wv2"].remove_NavigationCompleted(rec["tokenNavCompleted"])
        catch {
        }
    }
    if IsObject(rec["wv2"]) && rec["tokenWebMessage"] {
        try rec["wv2"].remove_WebMessageReceived(rec["tokenWebMessage"])
        catch {
        }
    }
    if IsObject(rec["ctrl"]) && rec["tokenGotFocus"] {
        try rec["ctrl"].remove_GotFocus(rec["tokenGotFocus"])
        catch {
        }
    }
    rec["tokenNavCompleted"] := 0
    rec["tokenWebMessage"] := 0
    rec["tokenGotFocus"] := 0
    if IsObject(rec["wv2"]) {
        try WebView2_NotifyHidden(rec["wv2"])
        catch {
        }
    }
    if IsObject(rec["ctrl"]) {
        try rec["ctrl"].IsVisible := false
        catch {
        }
        try rec["ctrl"].Close()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    rec["ctrl"] := 0
    rec["wv2"] := 0
    rec["ready"] := false
    if !preserveCreateInFlight {
        rec["createInFlight"] := false
        rec["createStarted"] := 0
        rec["pendingCreateHost"] := 0
        rec["lifecycleState"] := "closed"
    }
    SearchCenterWebLlm_SyncActiveGlobals()
}

SearchCenterWebLlm_DisposeActiveController() {
    global g_SCWebLlm_SiteHosts
    for sid, rec in g_SCWebLlm_SiteHosts
        SearchCenterWebLlm_DisposeSiteController(sid)
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Env, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    g_SCWebLlm_Ctrl := 0
    g_SCWebLlm_WV2 := 0
    g_SCWebLlm_Env := 0
    g_SCWebLlm_Ready := false
    g_SCWebLlm_TokenNavCompleted := 0
}

SearchCenterWebLlm_MakeNavCompletedHandler(siteId) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    return (sender, args) => SearchCenterWebLlm_OnNavigationCompleted(sid, sender, args)
}

SearchCenterWebLlm_MakeSiteGotFocusHandler(siteId) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    return (sender, args) => SearchCenterWebLlm_OnSiteGotFocus(sid, sender, args)
}

SearchCenterWebLlm_MakeSiteWebMessageHandler(siteId) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    return (sender, args) => SearchCenterWebLlm_OnSiteWebMessage(sid, sender, args)
}

SearchCenterWebLlm_OnSiteGotFocus(siteId, sender, args) {
    if !ScWebLlm_AllowEmbedFocusSteal()
        return
    SearchCenterWebLlm_FocusSiteFromInteraction(siteId, false)
}

SearchCenterWebLlm_OnSiteWebMessage(siteId, sender, args) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return
    raw := ""
    try raw := args.WebMessageAsJson
    catch {
        try raw := args.TryGetWebMessageAsString()
        catch {
        }
    }
    if (Trim(String(raw)) = "")
        return
    msg := 0
    if FuncExists("Jxon_Load") {
        try msg := Jxon_Load(raw)
        catch {
        }
    }
    if !(msg is Map)
        return
    typ := msg.Has("type") ? StrLower(Trim(String(msg["type"]))) : ""
    if (typ != "scwebllminteract")
        return
    msgSid := msg.Has("siteId") ? ScWebLlm_NormalizeSiteId(msg["siteId"]) : sid
    if (msgSid = "")
        msgSid := sid
    kind := msg.Has("kind") ? StrLower(Trim(String(msg["kind"]))) : "event"
    focusInput := (kind = "focus" || kind = "pointer")
    SearchCenterWebLlm_FocusSiteFromInteraction(msgSid, focusInput)
}

SearchCenterWebLlm_FocusSiteFromInteraction(siteId, focusInput := false) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWebLlm_ActiveSiteId
    if !ScWebLlm_ShouldShowWebEmbed() || !g_SCWebLlm_Visible
        return false
    if focusInput && !ScWebLlm_AllowEmbedFocusSteal()
        focusInput := false
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "" || !ScWebLlm_IsSiteEnabled(sid))
        return false
    try ScWebLlm_EnsureSiteInBroadcastLayout(sid)
    catch as e {
        ScWebLlm_Catch(e)
    }
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    prev := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    changed := (prev != sid)
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_ActiveSiteId := sid
    rec := SearchCenterWebLlm_SiteRecord(sid)
    siteReady := (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
    if !siteReady {
        try SearchCenterWebLlm_OpenSite(sid, false)
        catch as e {
            ScWebLlm_Catch(e)
        }
        rec := SearchCenterWebLlm_SiteRecord(sid)
        siteReady := (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
    }
    embedWCss := 0
    if (g_SCWebLlm_ContentRect is Map)
        embedWCss := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
    scrollChanged := false
    if (embedWCss > 0)
        scrollChanged := ScWebLlm_EnsureActiveColumnInView(SearchCenterWebLlm_ListLayoutSiteIds(), sid, embedWCss)
    if changed {
        SearchCenterWebLlm_SyncActiveGlobals()
    }
    if (scrollChanged || !siteReady) {
        global g_SCWebLlm_LastBoundsKey
        g_SCWebLlm_LastBoundsKey := ""
        SearchCenterWebLlm_ApplyBounds(h)
    } else {
        ScWebLlm_ApplyActiveSiteChrome(sid, h)
    }
    if changed
        SearchCenterWebLlm_PushChromeState()
    SearchCenterWebLlm_PulseFocusSite(sid)
    SearchCenterWebLlm_RaiseResizeRailsAboveHosts()
    if focusInput {
        SearchCenterWebLlm_FocusSiteInput(sid)
        SetTimer(SearchCenterWebLlm_FocusSiteInput.Bind(sid), -90)
    }
    return true
}

SearchCenterWebLlm_OnNavigationCompleted(siteId, sender, args) {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_PendingKeywords
    sid := ScWebLlm_NormalizeSiteId(siteId)
    ok := true
    try ok := args.IsSuccess
    catch {
    }
    if ok && sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        SearchCenterWebLlm_SaveState()
    else if !ok
        ScWebLlm_Trace("nav_fail", false, Map("site", sid))
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId))
        SearchCenterWebLlm_PushChromeState()
    if ok && (g_SCWebLlm_PendingKeywords is Map) && g_SCWebLlm_PendingKeywords.Has(sid)
        ScWebLlm_ScheduleSubmitKeyword(sid, g_SCWebLlm_PendingKeywords[sid], ScWebLlm_SubmitDelayForSite(sid, 650))
}

SearchCenterWebLlm_PushChromeState() {
    SearchCenterWebLlm_SyncActiveGlobals()
    global g_SCWebLlm_WV2, g_SCWebLlm_ActiveSiteId
    if !SearchCenterWebLlm_ControllerAlive()
        return
    payload := Map(
        "type", "webLlmChromeState",
        "siteId", g_SCWebLlm_ActiveSiteId,
        "loading", false,
        "canGoBack", false,
        "canGoForward", false,
        "url", "",
        "title", ""
    )
    try payload["canGoBack"] := !!g_SCWebLlm_WV2.CanGoBack
    catch {
    }
    try payload["canGoForward"] := !!g_SCWebLlm_WV2.CanGoForward
    catch {
    }
    try payload["url"] := Trim(String(g_SCWebLlm_WV2.Source))
    catch {
    }
    try payload["title"] := Trim(String(g_SCWebLlm_WV2.DocumentTitle))
    catch {
    }
    if FuncExists("ScWebLlm_PostJsonToHost") {
        try ScWebLlm_PostJsonToHost(payload)
        catch as e {
            ScWebLlm_Catch(e)
        }
    } else if FuncExists("SCWV_PostJson") {
        try SCWV_PostJson(payload)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

SearchCenterWebLlm_OnControllerReady(ctrl, siteId, url, expectedHost := 0) {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_MultiMobile, g_SCWebLlm_UnifiedMultiRectActive
    sid := ScWebLlm_NormalizeSiteId(siteId)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) {
        return
    }
    if !IsObject(ctrl) {
        curHost := Integer(rec.Get("hostHwnd", 0))
        if (expectedHost && Integer(expectedHost) != curHost) {
            ScWebLlm_Trace("controller_stale", false, Map("site", sid, "host", expectedHost, "cur", curHost))
            return
        }
        rec["createInFlight"] := false
        rec["createStarted"] := 0
        rec["pendingCreateHost"] := 0
        rec["lifecycleState"] := "failed"
        ScWebLlm_Trace("controller_fail", false, Map("site", sid))
        try TrayTip("联网搜索", (ScWebLlm_FindSite(sid) is Map ? ScWebLlm_FindSite(sid)["label"] : sid) . " 内嵌页启动失败", "Iconx 2")
        catch {
        }
        return
    }
    rec["createInFlight"] := false
    rec["createStarted"] := 0
    rec["pendingCreateHost"] := 0
    rec["ctrl"] := ctrl
    try rec["wv2"] := ctrl.CoreWebView2
    catch {
        rec["wv2"] := 0
    }
    if !IsObject(rec["wv2"]) {
        SearchCenterWebLlm_DisposeSiteController(sid)
        return
    }
    rec["ready"] := true
    rec["lifecycleState"] := "ready"
    try ctrl.DefaultBackgroundColor := 0xFF0B1220
    catch {
    }
    SearchCenterWebLlm_ApplyMobileSettings(rec["wv2"], sid)
    if FuncExists("ApplyWebView2PerformanceSettings") {
        try ApplyWebView2PerformanceSettings(rec["wv2"])
        catch {
        }
    }
    initScript := ScWebLlm_BuildInitScript(sid)
    if (initScript != "") {
        try rec["wv2"].AddScriptToExecuteOnDocumentCreatedAsync(initScript)
        catch as e {
            ScWebLlm_Trace("init_script_fail", false, Map("site", sid, "error", e.Message))
        }
    }
    try {
        if !rec["tokenNavCompleted"]
            rec["tokenNavCompleted"] := rec["wv2"].add_NavigationCompleted(SearchCenterWebLlm_MakeNavCompletedHandler(sid))
    } catch as e {
        ScWebLlm_Catch(e)
    }
    try {
        if !rec["tokenWebMessage"]
            rec["tokenWebMessage"] := rec["wv2"].add_WebMessageReceived(SearchCenterWebLlm_MakeSiteWebMessageHandler(sid))
    } catch as e {
        ScWebLlm_Catch(e)
    }
    try {
        if !rec["tokenGotFocus"] && IsObject(rec["ctrl"])
            rec["tokenGotFocus"] := rec["ctrl"].add_GotFocus(SearchCenterWebLlm_MakeSiteGotFocusHandler(sid))
    } catch as e {
        ScWebLlm_Catch(e)
    }
    try ctrl.IsVisible := true
    catch {
    }
    try {
        u := ScWebLlm_ResolveStartUrl(sid, url)
        if (rec.Has("pendingNavigateUrl") && !ScWebLlm_IsBlankEmbedUrl(rec["pendingNavigateUrl"])) {
            u := ScWebLlm_ResolveStartUrl(sid, rec["pendingNavigateUrl"])
            rec["pendingNavigateUrl"] := ""
        }
        if !ScWebLlm_IsBlankEmbedUrl(u)
            rec["wv2"].Navigate(u)
    } catch as e {
        ScWebLlm_Catch(e)
    }
    SearchCenterWebLlm_SyncActiveGlobals()
    SetTimer(SearchCenterWebLlm_OnControllerReadyLayoutTick.Bind(sid), -1)
    if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
        try WebView2_NotifyShown(rec["wv2"])
        catch {
        }
    }
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId))
        SearchCenterWebLlm_PushChromeState()
    ScWebLlm_Trace("site_open", true, Map("site", sid, "multi", !!g_SCWebLlm_MultiMobile))
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive {
        h := ScWebLlm_GetEmbedParentHwnd()
        if h {
            try SearchCenterWebLlm_ApplyBounds(h)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
    }
}

SearchCenterWebLlm_OnControllerReadyLayoutTick(siteId, *) {
    global g_SCWebLlm_UnifiedMultiRectActive
    sid := ScWebLlm_NormalizeSiteId(siteId)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) || !rec.Get("ready", false)
        return
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive {
        h := ScWebLlm_GetEmbedParentHwnd()
        if h {
            try SearchCenterWebLlm_ApplyBounds(h)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        return
    } else {
        try SearchCenterWebLlm_ApplyBounds()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    ScWebLlm_ScheduleBoundsRetries()
}

SearchCenterWebLlm_QueueOpenSite(siteId, forceNavigate := false, navigateUrl := "") {
    global g_SCWebLlm_PendingOpenRequest
    g_SCWebLlm_PendingOpenRequest := Map(
        "siteId", ScWebLlm_NormalizeSiteId(siteId),
        "forceNavigate", !!forceNavigate,
        "navigateUrl", Trim(String(navigateUrl))
    )
    return true
}

SearchCenterWebLlm_OpenSite(siteId, forceNavigate := false, navigateUrl := "") {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_MultiMobile
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    if !ScWebLlm_IsSiteEnabled(sid) {
        try TrayTip("联网搜索", "该 AI 站点暂不支持内嵌：" . sid, "Icon! 2")
        catch {
        }
        return false
    }
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map)
        return false
    if rec["createInFlight"] || rec.Get("lifecycleState", "") = "creating" {
        if (navigateUrl != "")
            rec["pendingNavigateUrl"] := ScWebLlm_ResolveStartUrl(sid, navigateUrl)
        return true
    }
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)) {
        st := SearchCenterWebLlm_LoadState()
        st["activeSiteId"] := sid
        global g_SCWebLlm_StateCache
        g_SCWebLlm_StateCache := st
    }
    targetUrl := ScWebLlm_ResolveStartUrl(sid, navigateUrl)
    if !SearchCenterWebLlm_HostAlive() {
        if !g_SCWebLlm_ParentHwnd
            return false
    }
    parentHwnd := g_SCWebLlm_ParentHwnd
    if !parentHwnd
        return false
    global g_SCWebLlm_Visible
    g_SCWebLlm_Visible := true
    ScWebLlm_EnsureFallbackContentRect()
    if (rec["ready"] && IsObject(rec["wv2"])) {
        hostHwnd := SearchCenterWebLlm_EnsureSiteHost(parentHwnd, sid)
        if !hostHwnd
            return false
        SearchCenterWebLlm_ApplyBounds(parentHwnd)
        global g_SCWebLlm_PendingKeywords
        if (forceNavigate && targetUrl != "") {
            lastUrl := String(rec.Get("lastNavigateUrl", ""))
            lastTick := Integer(rec.Get("lastNavigateTick", 0))
            if !(lastUrl = targetUrl && A_TickCount - lastTick < 8000) {
                rec["lastNavigateUrl"] := targetUrl
                rec["lastNavigateTick"] := A_TickCount
                try rec["wv2"].Navigate(targetUrl)
                catch as e {
                    ScWebLlm_Catch(e)
                }
            }
        } else if (g_SCWebLlm_PendingKeywords is Map) && g_SCWebLlm_PendingKeywords.Has(sid) {
            ScWebLlm_ScheduleSubmitKeyword(sid, g_SCWebLlm_PendingKeywords[sid], ScWebLlm_SubmitDelayForSite(sid, 700))
        }
        SearchCenterWebLlm_SyncActiveGlobals()
        return true
    }
    hostHwnd := SearchCenterWebLlm_EnsureSiteHost(parentHwnd, sid)
    if !hostHwnd
        return false
    rec["createInFlight"] := true
    rec["createStarted"] := A_TickCount
    rec["pendingCreateHost"] := hostHwnd
    rec["lifecycleState"] := "creating"
    rec["lastNavigateUrl"] := targetUrl
    rec["lastNavigateTick"] := A_TickCount
    SearchCenterWebLlm_DisposeSiteController(sid, true)
    rec["lifecycleState"] := "creating"
    ScWebLlm_Trace("open_site", true, Map("site", sid, "url", targetUrl, "host", hostHwnd))
    if !FuncExists("WebView2_CreateWithSharedEnvAsync") && !FuncExists("WebView2_CreateWithSiteDataDirAsync") {
        rec["createInFlight"] := false
        rec["createStarted"] := 0
        rec["pendingCreateHost"] := 0
        ScWebLlm_Trace("open_site_fail", false, Map("site", sid, "reason", "no_shared_env"))
        return false
    }
    readyCb := (ctrl) => SearchCenterWebLlm_OnControllerReady(ctrl, sid, targetUrl, hostHwnd)
    if ScWebLlm_SiteUsesIsolatedProfile(sid) && FuncExists("WebView2_CreateWithSiteDataDirAsync") {
        WebView2_CreateWithSiteDataDirAsync(hostHwnd, sid, readyCb, "searchcenter_sc_web_llm_" . sid)
    } else if FuncExists("WebView2_CreateWithSharedEnvAsync") {
        WebView2_CreateWithSharedEnvAsync(hostHwnd, readyCb, "searchcenter_sc_web_llm_" . sid)
    } else {
        rec["createInFlight"] := false
        rec["createStarted"] := 0
        rec["pendingCreateHost"] := 0
        ScWebLlm_Trace("open_site_fail", false, Map("site", sid, "reason", "no_webview_create"))
        return false
    }
    return true
}

SearchCenterWebLlm_OpenSiteDelayed(siteId, forceNavigate := false, *) {
    SearchCenterWebLlm_OpenSite(siteId, forceNavigate)
}

SearchCenterWebLlm_SubmitToSiteDelayed(siteId, keyword, *) {
    SearchCenterWebLlm_SubmitToSite(siteId, keyword)
}

SearchCenterWebLlm_HasReadySites() {
    for sid in SearchCenterWebLlm_ListLayoutSiteIds() {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
            return true
    }
    return false
}

SearchCenterWebLlm_EnsureMissingSites(forceNavigate := false, parentHwnd := 0) {
    global g_SCWebLlm_UnifiedMultiRectActive
    ok := false
    pending := 0
    inFlight := 0
    hwnd := Integer(parentHwnd)
    if !hwnd
        hwnd := ScWebLlm_GetEmbedParentHwnd()
    toLoad := SearchCenterWebLlm_ListSitesToLoad(hwnd)
    for sid in toLoad {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if (rec is Map) && rec.Get("createInFlight", false)
            inFlight++
    }
    maxConcurrent := 2
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive {
        maxConcurrent := Min(ScWebLlm_UnifiedMaxActiveAiEmbeds(), 4)
        if (maxConcurrent < 2)
            maxConcurrent := 2
    }
    for sid in toLoad {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            continue
        if rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
            continue
        if rec.Get("createInFlight", false) {
            started := Integer(rec.Get("createStarted", 0))
            if (started > 0 && (A_TickCount - started > 20000)) {
                rec["createInFlight"] := false
                rec["createStarted"] := 0
                rec["lifecycleState"] := "failed"
            } else {
                continue
            }
        }
        if (inFlight >= maxConcurrent) {
            pending += 1
            delay := 180 + pending * 120
            SetTimer(SearchCenterWebLlm_EnsureMissingSitesDelayed.Bind(forceNavigate), -delay)
            ok := true
            continue
        }
        delay := pending * 30
        if (delay <= 0)
            ok := SearchCenterWebLlm_OpenSite(sid, forceNavigate) || ok
        else
            SetTimer(SearchCenterWebLlm_OpenSiteDelayed.Bind(sid, forceNavigate), -delay)
        ok := true
        pending += 1
        inFlight += 1
    }
    return ok
}

SearchCenterWebLlm_EnsureMissingSitesDelayed(forceNavigate := false, *) {
    SearchCenterWebLlm_EnsureMissingSites(forceNavigate)
}

ScWebLlm_IsActiveSiteReady() {
    global g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    rec := SearchCenterWebLlm_SiteRecord(sid)
    return (rec is Map) && rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
}

ScWebLlm_EnsureActiveSiteOpened(forceNavigate := false) {
    global g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "" || !ScWebLlm_IsSiteEnabled(sid))
        sid := ScWebLlm_PickSiteFromEngines(SearchCenterSelectedEngines)
    if (sid = "" || !ScWebLlm_IsSiteEnabled(sid))
        sid := ScWebLlm_DefaultSiteId()
    g_SCWebLlm_ActiveSiteId := sid
    return SearchCenterWebLlm_OpenSite(sid, forceNavigate)
}

ScWebLlm_ScheduleEmbedResumeCheck() {
    SetTimer(ScWebLlm_EmbedResumeCheck, -160)
    SetTimer(ScWebLlm_EmbedResumeCheck, -480)
    SetTimer(ScWebLlm_EmbedResumeCheck, -960)
}

ScWebLlm_EmbedResumeCheck(*) {
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    if !ScWebLlm_UnifiedEmbedBootstrapReady()
        return
    if ScWebLlm_IsActiveSiteReady()
        return
    if !SearchCenterWebLlm_CanBootstrapEmbed()
        return
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        return
    try ScWebLlm_EnsureActiveSiteOpened(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    try SearchCenterWebLlm_EnsureMissingSites(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    try SearchCenterWebLlm_ShowReadySites(h)
    catch as e {
        ScWebLlm_Catch(e)
    }
    try SearchCenterWebLlm_ApplyBounds(h)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_OpenAllSites(forceNavigate := false) {
    global g_SCWebLlm_MultiMobile, g_SCWebLlm_ActiveSiteId
    if !g_SCWebLlm_MultiMobile {
        sid := ScWebLlm_DefaultSiteId()
        if (g_SCWebLlm_ActiveSiteId != "")
            sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        return SearchCenterWebLlm_OpenSite(sid, forceNavigate)
    }
    activeSid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (activeSid = "" || !ScWebLlm_IsSiteEnabled(activeSid))
        activeSid := ScWebLlm_PickSiteFromEngines(SearchCenterSelectedEngines)
    if (activeSid = "")
        activeSid := ScWebLlm_DefaultSiteId()
    g_SCWebLlm_ActiveSiteId := activeSid
    ok := false
    if (activeSid != "")
        ok := SearchCenterWebLlm_OpenSite(activeSid, forceNavigate) || ok
    try ok := SearchCenterWebLlm_EnsureMissingSites(forceNavigate) || ok
    catch as e {
        ScWebLlm_Catch(e)
    }
    return ok
}

ScWebLlm_ResolveClientRect(parentHwnd, &left, &top, &w, &h) {
    global g_SCWebLlm_ContentRect, g_SCWV_Ctrl
    ph := Integer(parentHwnd)
    if !ph
        ph := ScWebLlm_GetEmbedParentHwnd()
    if (g_SCWebLlm_ContentRect is Map) && ph && FuncExists("_SCWV_ViewportRectToParentClient") {
        try {
            if _SCWV_ViewportRectToParentClient(g_SCWebLlm_ContentRect, ph, &left, &top, &w, &h) {
                if (w >= 200 && h >= 140)
                    return true
            }
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if (g_SCWebLlm_ContentRect is Map) {
        cssL := Integer(g_SCWebLlm_ContentRect.Get("left", 0))
        cssT := Integer(g_SCWebLlm_ContentRect.Get("top", 220))
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        cssH := Integer(g_SCWebLlm_ContentRect.Get("height", 0))
        if (cssW >= 160 && cssH >= 80) {
            sc := ScWebLlm_GetRasterScale()
            bl := 0
            bt := 0
            if IsObject(g_SCWV_Ctrl) {
                try {
                    rc := g_SCWV_Ctrl.Bounds
                    bl := Integer(rc.left)
                    bt := Integer(rc.top)
                } catch as e {
                    ScWebLlm_Catch(e)
                }
            }
            left := Round(cssL * sc) + bl
            top := Round(cssT * sc) + bt
            w := Max(Round(cssW * sc), 200)
            h := Max(Round(cssH * sc), 140)
            return true
        }
    }
    ph := Integer(parentHwnd)
    if !ph
        ph := ScWebLlm_GetEmbedParentHwnd()
    cssL := 0
    cssT := 220
    cssW := 800
    cssH := 500
    if (g_SCWebLlm_ContentRect is Map) {
        cssL := Integer(g_SCWebLlm_ContentRect.Get("left", 0))
        cssT := Integer(g_SCWebLlm_ContentRect.Get("top", 220))
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 800))
        cssH := Integer(g_SCWebLlm_ContentRect.Get("height", 500))
    }
    sc := ScWebLlm_GetRasterScale()
    left := Round(cssL * sc)
    top := Round(cssT * sc)
    w := Round(cssW * sc)
    h := Round(cssH * sc)
    if (w < 200 || h < 140) {
        ph := Integer(parentHwnd)
        if !ph
            return false
        try WinGetClientPos(, , &cw, &ch, ph)
        catch {
            return false
        }
        if (cw < 200 || ch < 160)
            return false
        left := 0
        top := Min(Round(ch * 0.28), Max(120, Round(cssT * sc)))
        w := cw
        h := Max(140, ch - top)
    }
    return (w >= 200 && h >= 140)
}

ScWebLlm_ResolveEmbedScreenRect(&left, &top, &w, &h) {
    global g_SCWebLlm_ContentRect
    if !(g_SCWebLlm_ContentRect is Map)
        return false
    if FuncExists("_SCWV_BoundsMapToScreen") {
        try return _SCWV_BoundsMapToScreen(g_SCWebLlm_ContentRect, &left, &top, &w, &h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return false
}

SearchCenterWebLlm_InvalidateLayoutCaches(resetScroll := false) {
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ChildHostBoundsCache, g_SCWebLlm_SiteBoundsSig, g_SCWebLlm_ScrollX, g_SCWebLlm_HostClipCache
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_ChildHostBoundsCache := Map()
    g_SCWebLlm_HostClipCache := Map()
    g_SCWebLlm_SiteBoundsSig := Map()
    if resetScroll
        g_SCWebLlm_ScrollX := 0
}

SearchCenterWebLlm_PrepareForWebModeShow(skipEmbedResume := false) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ScrollX, g_SCWebLlm_ContentRectReady
    wasShowing := g_SCWebLlm_Visible && g_SCWebLlm_ContentRectReady
    g_SCWebLlm_Visible := true
    if !wasShowing {
        g_SCWebLlm_ScrollX := 0
        SearchCenterWebLlm_InvalidateLayoutCaches(false)
    }
    SearchCenterWebLlm_MarkEmbedRequested()
    ScWebLlm_InstallEmbedScrollInputHook()
    ScWebLlm_BeginEmbedFocusGuard(8000)
    if !skipEmbedResume
        ScWebLlm_ScheduleEmbedResumeCheck()
}

ScWebLlm_EnsureFallbackContentRect(markReady := false) {
    global g_SCWebLlm_ContentRect, g_SCWebLlm_ContentRectReady, g_SCWV_Gui
    if (g_SCWebLlm_ContentRectReady && (g_SCWebLlm_ContentRect is Map) && Integer(g_SCWebLlm_ContentRect.Get("width", 0)) >= 160)
        return true
    if !IsObject(g_SCWV_Gui)
        return false
    try {
        WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
        if (cw < 200 || ch < 200)
            return false
        sc := ScWebLlm_GetRasterScale()
        cssW := Max(160, Round(Float(cw) / Max(sc, 0.01)))
        cssH := Max(80, Round(Float(ch) / Max(sc, 0.01)))
        cssT := Max(120, Round(Float(ch) / Max(sc, 0.01) * 0.34))
        g_SCWebLlm_ContentRect := Map(
            "left", 0,
            "top", cssT,
            "width", cssW,
            "height", Max(140, Round(Float(ch) / Max(sc, 0.01) * 0.52))
        )
        if (sc > 0.1 && sc < 10)
            g_SCWebLlm_ContentRect["dpr"] := sc
        if markReady
            g_SCWebLlm_ContentRectReady := true
        return true
    } catch as e {
        ScWebLlm_Catch(e)
    }
    return false
}

ScWebLlm_ScheduleBoundsRetries() {
    global g_SCWebLlm_BoundsRetryScheduled
    if g_SCWebLlm_BoundsRetryScheduled
        return
    g_SCWebLlm_BoundsRetryScheduled := true
    SetTimer(ScWebLlm_BoundsRetryTick, -220)
}

ScWebLlm_BoundsRetryTick() {
    global g_SCWebLlm_BoundsRetryScheduled
    g_SCWebLlm_BoundsRetryScheduled := false
    try SearchCenterWebLlm_ApplyBounds()
    catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_EmbedBootstrapTick() {
    global g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapWaitCount
    g_SCWebLlm_BootstrapScheduled := false
    if g_SCWebLlm_BootstrapInFlight
        return
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    if !ScWebLlm_UnifiedEmbedBootstrapReady()
        return
    if !SearchCenterWebLlm_CanBootstrapEmbed() {
        g_SCWebLlm_BootstrapWaitCount += 1
        if (g_SCWebLlm_BootstrapWaitCount >= 12)
            ScWebLlm_EnsureFallbackContentRect(true)
        if !SearchCenterWebLlm_CanBootstrapEmbed() {
            if (g_SCWebLlm_BootstrapWaitCount < 24)
                ScWebLlm_ScheduleEmbedBootstrap()
            return
        }
    }
    g_SCWebLlm_BootstrapInFlight := true
    try SearchCenterWebLlm_EnsureEmbedSitesLoaded(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    g_SCWebLlm_BootstrapInFlight := false
}

ScWebLlm_ScheduleEmbedBootstrap() {
    global g_SCWebLlm_BootstrapScheduled
    if g_SCWebLlm_BootstrapScheduled
        return
    g_SCWebLlm_BootstrapScheduled := true
    SetTimer(ScWebLlm_EmbedBootstrapTick, -48)
}

SearchCenterWebLlm_StartEmbedWatchdog() {
    global g_SCWebLlm_WatchdogToken
    if g_SCWebLlm_WatchdogToken
        return
    g_SCWebLlm_WatchdogToken := A_TickCount
    token := g_SCWebLlm_WatchdogToken
    SetTimer((*) => SearchCenterWebLlm_EmbedWatchdogTick(token, 0), -2500)
}

SearchCenterWebLlm_EmbedWatchdogTick(token, n) {
    global g_SCWebLlm_WatchdogToken, g_SCWebLlm_EmbedBootstrapped
    if (token != g_SCWebLlm_WatchdogToken)
        return
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    if ScWebLlm_SitesToLoadReady() {
        g_SCWebLlm_WatchdogToken := 0
        return
    }
    if !g_SCWebLlm_EmbedBootstrapped
        ScWebLlm_ScheduleEmbedBootstrap()
    else {
        try SearchCenterWebLlm_EnsureMissingSites(false)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if (n < 4)
        SetTimer((*) => SearchCenterWebLlm_EmbedWatchdogTick(token, n + 1), -4000)
}

SearchCenterWebLlm_MarkEmbedRequested() {
    global g_SCWebLlm_EmbedRequested
    g_SCWebLlm_EmbedRequested := true
}

SearchCenterWebLlm_ClearEmbedRequested() {
    global g_SCWebLlm_EmbedRequested
    g_SCWebLlm_EmbedRequested := false
}

SearchCenterWebLlm_CanBootstrapEmbed() {
    global g_SCWV_Ctrl, g_SCWebLlm_ContentRectReady
    if !IsObject(g_SCWV_Ctrl)
        return false
    if !ScWebLlm_GetEmbedParentHwnd()
        return false
    if !ScWebLlm_UnifiedEmbedBootstrapReady()
        return false
    if !g_SCWebLlm_ContentRectReady
        return false
    return true
}

SearchCenterWebLlm_SetContentRect(rect) {
    global g_SCWebLlm_PendingContentRect
    if !(rect is Map)
        return
    g_SCWebLlm_PendingContentRect := Map(
        "left", Integer(rect.Get("left", 0)),
        "top", Integer(rect.Get("top", 220)),
        "width", Integer(rect.Get("width", 0)),
        "height", Integer(rect.Get("height", 0)),
        "dpr", rect.Has("dpr") ? Float(rect["dpr"]) : 0
    )
    SetTimer(ScWebLlm_ApplyPendingContentRect, -48)
}

ScWebLlm_ApplyPendingContentRect() {
    global g_SCWebLlm_PendingContentRect
    rect := g_SCWebLlm_PendingContentRect
    g_SCWebLlm_PendingContentRect := 0
    if !(rect is Map)
        return
    SearchCenterWebLlm_ApplyContentRectNow(rect)
}

SearchCenterWebLlm_ApplyContentRectNow(rect) {
    global g_SCWebLlm_ContentRect, g_SCWebLlm_Visible, g_SCWebLlm_ContentRectReady, g_SCWebLlm_ParentHwnd
    global g_SCWebLlm_LastBoundsKey
    if !(rect is Map)
        return
    if !ScWebLlm_ShouldShowWebEmbed() {
        SearchCenterWebLlm_TeardownEmbed()
        return
    }
    if FuncExists("_SCWV_ArmWebEmbedMinimizeGuard") {
        try _SCWV_ArmWebEmbedMinimizeGuard(8000)
        catch {
        }
    }
    SearchCenterWebLlm_MarkEmbedRequested()
    g_SCWebLlm_Visible := true
    w := Max(0, Integer(rect.Get("width", 0)))
    h := Max(0, Integer(rect.Get("height", 0)))
    prevW := 0
    prevH := 0
    prevT := 0
    prevDpr := 0.0
    if (g_SCWebLlm_ContentRect is Map) {
        prevW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        prevH := Integer(g_SCWebLlm_ContentRect.Get("height", 0))
        prevT := Integer(g_SCWebLlm_ContentRect.Get("top", 0))
        if g_SCWebLlm_ContentRect.Has("dpr")
            prevDpr := Float(g_SCWebLlm_ContentRect["dpr"])
    }
    newDpr := rect.Has("dpr") ? Float(rect["dpr"]) : 0.0
    if (w > prevW + 48 || h > prevH + 48 || Abs(Integer(rect.Get("top", 0)) - prevT) > 12 || (newDpr > 0.1 && Abs(newDpr - prevDpr) > 0.05))
        SearchCenterWebLlm_InvalidateLayoutCaches(false)
    g_SCWebLlm_ContentRect := Map(
        "left", Integer(rect.Get("left", 0)),
        "top", Integer(rect.Get("top", 220)),
        "width", Max(200, w),
        "height", Max(140, h)
    )
    if rect.Has("dpr") {
        dpr := Float(rect["dpr"])
        if (dpr > 0.1 && dpr < 10)
            g_SCWebLlm_ContentRect["dpr"] := dpr
    }
    parent := g_SCWebLlm_ParentHwnd
    g_SCWebLlm_ContentRectReady := (w >= 160 && h >= 80)
    if g_SCWebLlm_ContentRectReady
        g_SCWebLlm_BootstrapWaitCount := 0
    if g_SCWebLlm_ContentRectReady {
        siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
        if ScWebLlm_ClampScrollForFill(siteIds, Max(200, w))
            g_SCWebLlm_LastBoundsKey := ""
    }
    SearchCenterWebLlm_ApplyBounds()
    try SearchCenterWebLlm_EnsureMissingSites(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    parentHwnd := ScWebLlm_GetEmbedParentHwnd()
    if g_SCWebLlm_ContentRectReady && parentHwnd {
        if !SearchCenterWebLlm_HasReadySites() {
            global g_SCWebLlm_EmbedBootstrapped
            forceHome := ScWebLlm_IsUnifiedWorkbenchHost() ? false : !g_SCWebLlm_EmbedBootstrapped
            try SearchCenterWebLlm_EnsureEmbedSitesLoaded(forceHome, parentHwnd)
            catch as e {
                ScWebLlm_Catch(e)
            }
        } else {
            try SearchCenterWebLlm_ShowReadySites(parentHwnd)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
    }
    ScWebLlm_ScheduleBoundsRetries()
    if !g_SCWebLlm_EmbedBootstrapped
        SetTimer(ScWebLlm_EmbedBootstrapTick, -1)
    else if !SearchCenterWebLlm_HasReadySites() && !ScWebLlm_IsUnifiedWorkbenchHost()
        ScWebLlm_ScheduleEmbedBootstrap()
    if !g_SCWebLlm_EmbedBootstrapped
        SearchCenterWebLlm_StartEmbedWatchdog()
    ScWebLlm_ScheduleEmbedResumeCheck()
}

ScWebLlm_ComputeSiteColumnLayout(siteIds, activeSiteId, embedLeft, embedTop, embedW, embedH, &colLeft, &colTop, &colW, &colH, index, lastColFillCss := 0) {
    global g_SCWebLlm_ScrollX
    n := siteIds.Length
    if (n < 1 || index < 0 || index >= n)
        return false
    sid := siteIds[index + 1]
    embedWCss := ScWebLlm_PhysicalToCss(embedW)
    colWCss := ScWebLlm_ResolveColumnWidth(sid, siteIds, embedWCss)
    if (index = n - 1 && lastColFillCss > 0)
        colWCss += Integer(lastColFillCss)
    virtualXPhys := 0
    Loop index {
        virtualXPhys += ScWebLlm_CssToPhysical(ScWebLlm_ResolveColumnWidth(siteIds[A_Index], siteIds, embedWCss))
        virtualXPhys += ScWebLlm_CssToPhysical(ScWebLlm_ColumnGap())
    }
    scrollPhys := ScWebLlm_CssToPhysical(g_SCWebLlm_ScrollX)
    colLeft := embedLeft + virtualXPhys - scrollPhys
    colTop := embedTop
    colW := ScWebLlm_CssToPhysical(colWCss)
    colH := embedH
    return (colWCss >= ScWebLlm_AbsMinColumnWidth() && colH >= 140 && colW > 0)
}

SearchCenterWebLlm_ApplyBounds(parentHwnd := 0) {
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_ContentRect
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_Visible, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_MultiMobile
    global g_SCWebLlm_ContentRectReady, g_SCWebLlm_SiteBoundsSig, g_SCWebLlm_LastColFillCss, g_SCWebLlm_ScrollOnlyPass
    global g_SCWebLlm_UnifiedMultiRectActive
    if ScWebLlm_ShouldSkipEmbedWinOps()
        return false
    if ScWebLlm_IsUnifiedLayoutPaused()
        return false
    if !ScWebLlm_ShouldShowWebEmbed() {
        SearchCenterWebLlm_TeardownEmbed()
        return false
    }
    if !g_SCWebLlm_ContentRectReady
        return false
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : g_SCWebLlm_ParentHwnd
    if !hwnd || !g_SCWebLlm_Visible
        return false
    g_SCWebLlm_ParentHwnd := hwnd
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive
        return ScWebLlm_UnifiedMultiRectApplyBounds(hwnd)
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    resolved := ScWebLlm_ResolveClientRect(hwnd, &embedLeft, &embedTop, &embedW, &embedH)
    if !resolved
        return false
    embedW := ScWebLlm_ExpandEmbedWidthToParent(hwnd, embedLeft, embedW)
    embedH := ScWebLlm_FullEmbedColumnHeight(hwnd, embedTop, Max(140, Integer(embedH)))
    ScWebLlm_EnsureEmbedBackdrop(hwnd, embedLeft, embedTop, embedW, embedH)
    embedWCss := ScWebLlm_ResolveEmbedViewportCss(embedW)
    if (embedWCss <= 0)
        embedWCss := ScWebLlm_PhysicalToCss(embedW)
    dragActive := ScWebLlm_IsRailDragging()
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    if !g_SCWebLlm_MultiMobile {
        sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        if (sid = "")
            sid := ScWebLlm_DefaultSiteId()
        siteIds := [sid]
    }
    scrollClamped := ScWebLlm_ClampScrollForFill(siteIds, embedWCss)
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (scrollClamped)
        g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_LastColFillCss := ScWebLlm_ComputeStripFillExtraCss(siteIds, embedWCss)
    key := embedLeft . "x" . embedTop . "x" . embedW . "x" . embedH . "x" . siteIds.Length
        . "x" . g_SCWebLlm_ScrollX . "x" . ScWebLlm_ComputeVirtualStripWidth(siteIds, embedWCss)
    if (g_SCWebLlm_LastColFillCss > 0)
        key .= "xfill:" . g_SCWebLlm_LastColFillCss
    if (g_SCWebLlm_ColumnWidths is Map) {
        for sid in siteIds {
            if g_SCWebLlm_ColumnWidths.Has(sid)
                key .= "x" . sid . ":" . g_SCWebLlm_ColumnWidths[sid]
        }
    }
    if (key = g_SCWebLlm_LastBoundsKey && !dragActive) {
        ScWebLlm_EnsureEmbedHostStack(g_SCWebLlm_ActiveSiteId)
        try SearchCenterWebLlm_EnsureMissingSites(false, hwnd)
        catch as e {
            ScWebLlm_Catch(e)
        }
        return true
    }
    g_SCWebLlm_LastBoundsKey := key
    g_SCWebLlm_LastRaisedHostHwnd := 0
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    fillCss := Integer(g_SCWebLlm_LastColFillCss)
    allColumnsFit := (ScWebLlm_ComputeVirtualStripWidth(siteIds, embedWCss) + fillCss <= embedWCss + 1)
    idx := 0
    for sid in siteIds {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            continue
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        if !ScWebLlm_ComputeSiteColumnLayout(siteIds, activeNorm, embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, idx, fillCss) {
            hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
            if hostHwnd
                SearchCenterWebLlm_PositionChildHost(hostHwnd, 0, 0, 0, 0, false, hwnd)
            if IsObject(rec["ctrl"]) {
                try rec["ctrl"].IsVisible := false
                catch {
                }
            }
            idx += 1
            continue
        }
        inView := (colW > 0 && colH > 0) && (allColumnsFit || ScWebLlm_ColumnIntersectsViewport(colL, colW, embedLeft, embedW))
        if !inView && allColumnsFit
            inView := (colW > 0 && colH > 0)
        hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
        if !hostHwnd
            hostHwnd := SearchCenterWebLlm_EnsureSiteHost(hwnd, sid)
        if hostHwnd {
            showCol := inView && (colW > 0 && colH > 0)
            if showCol {
                SearchCenterWebLlm_PositionChildHost(hostHwnd, colL, colT, colW, colH, true, hwnd)
                ScWebLlm_ApplyHostViewportClip(hostHwnd, colL, colW, colH, embedLeft, embedW)
            } else {
                ScWebLlm_ClearHostViewportClip(hostHwnd)
                SearchCenterWebLlm_PositionChildHost(hostHwnd, 0, 0, 0, 0, false, hwnd)
            }
        }
        boundsSig := colW . "x" . colH
        skipWebBounds := (dragActive || g_SCWebLlm_ScrollOnlyPass) && g_SCWebLlm_SiteBoundsSig.Has(sid) && (g_SCWebLlm_SiteBoundsSig[sid] = boundsSig)
        if !skipWebBounds
            g_SCWebLlm_SiteBoundsSig[sid] := boundsSig
        if IsObject(rec["ctrl"]) && hostHwnd && inView && !skipWebBounds {
            try {
                WinGetClientPos(, , &hw, &hh, hostHwnd)
                if (hw > 0 && hh > 0) {
                    rc := WebView2.RECT()
                    rc.left := 0
                    rc.top := 0
                    rc.right := hw
                    rc.bottom := hh
                    rec["ctrl"].Bounds := rc
                    rec["ctrl"].NotifyParentWindowPositionChanged()
                }
            } catch as e {
                ScWebLlm_Catch(e)
            }
            try rec["ctrl"].IsVisible := true
            catch {
            }
            if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
                try WebView2_NotifyShown(rec["wv2"])
                catch {
                }
            }
        } else if IsObject(rec["ctrl"]) && hostHwnd && inView && skipWebBounds {
            try rec["ctrl"].NotifyParentWindowPositionChanged()
            catch as e {
                ScWebLlm_Catch(e)
            }
            try rec["ctrl"].IsVisible := true
            catch {
            }
        } else if IsObject(rec["ctrl"]) && hostHwnd && !inView {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
        idx += 1
    }
    layoutSet := Map()
    for sid in siteIds
        layoutSet[sid] := true
    global g_SCWebLlm_SiteHosts
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map) || layoutSet.Has(sid)
            continue
        if rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_PositionChildHost(rec["hostHwnd"], 0, 0, 0, 0, false, hwnd)
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
    }
    SearchCenterWebLlm_ApplyResizeRails(siteIds, embedLeft, embedTop, embedW, embedH, hwnd, fillCss)
    if dragActive
        SearchCenterWebLlm_HideFocusGlow(hwnd)
    else
        SearchCenterWebLlm_ApplyFocusGlow(siteIds, activeNorm, embedLeft, embedTop, embedW, embedH, hwnd, fillCss)
    for sid in SearchCenterWebLlm_ListSitesToLoad(hwnd) {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            continue
        if rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
            continue
        if rec.Get("createInFlight", false)
            continue
        try SearchCenterWebLlm_OpenSite(sid, false)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if !dragActive && !g_SCWebLlm_ScrollOnlyPass && (fillCss > 0 || scrollClamped)
        ScWebLlm_PushColumnLayoutToWeb(false, false)
    if !dragActive
        ScWebLlm_EnsureEmbedHostStack(activeNorm)
    SearchCenterWebLlm_SyncActiveGlobals()
    if ScWebLlm_SitesToLoadReady() {
        global g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapScheduled
        if !g_SCWebLlm_BootstrapInFlight && !g_SCWebLlm_BootstrapScheduled
            ScWebLlm_EndEmbedFocusGuard()
    }
    return true
}

ScWebLlm_ApplyBoundsDuringRailDrag() {
    global g_SCWebLlm_LastBoundsKey
    g_SCWebLlm_LastBoundsKey := ""
    SearchCenterWebLlm_ApplyBounds()
}

SearchCenterWebLlm_Show(parentHwnd) {
    return SearchCenterWebLlm_EnsureEmbedSitesLoaded(false, parentHwnd)
}

SearchCenterWebLlm_EnsureEmbedSitesLoaded(forceNavigateHome := false, parentHwnd := 0) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, SearchCenterSelectedEngines
    global g_SCWebLlm_ContentRectReady, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ActiveSiteId
    global g_SCWebLlm_EmbedBootstrapped, g_SCWV_Ctrl
    static catalogValidated := false
    if !catalogValidated {
        catalogValidated := true
        try ScWebLlm_ValidateSiteCatalog()
        catch {
        }
    }
    ScWebLlm_Trace("ensure_enter", true, Map("force", !!forceNavigateHome, "ready", !!g_SCWebLlm_ContentRectReady, "boot", !!g_SCWebLlm_EmbedBootstrapped))
    if !ScWebLlm_ShouldShowWebEmbed() {
        ScWebLlm_Trace("ensure_skip", false, Map("reason", "should_not_embed"))
        return false
    }
    if !ScWebLlm_UnifiedEmbedBootstrapReady() {
        ScWebLlm_Trace("ensure_skip", false, Map("reason", "unified_wait_layout"))
        if ScWebLlm_IsUnifiedWorkbenchHost()
            ScWebLlm_UnifiedScheduleLayoutBootstrap()
        return false
    }
    ScWebLlm_BeginEmbedFocusGuard(8000)
    if !SearchCenterWebLlm_CanBootstrapEmbed() {
        ScWebLlm_Trace("ensure_wait", false, Map("reason", "not_ready", "wait", g_SCWebLlm_BootstrapWaitCount))
        return false
    }
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        h := Integer(parentHwnd)
    if !h {
        ScWebLlm_Trace("ensure_abort", false, Map("reason", "no_parent_hwnd"))
        return false
    }
    SearchCenterWebLlm_MarkEmbedRequested()
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    if !g_SCWebLlm_ContentRectReady
        g_SCWebLlm_LastBoundsKey := ""
    if !(ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive) {
        st := SearchCenterWebLlm_LoadState()
        sid := st.Has("activeSiteId") ? ScWebLlm_NormalizeSiteId(st["activeSiteId"]) : ""
        if !ScWebLlm_IsSiteEnabled(sid)
            sid := ScWebLlm_PickSiteFromEngines(SearchCenterSelectedEngines)
        g_SCWebLlm_ActiveSiteId := sid
    }
    navHome := !!forceNavigateHome
    if ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_UnifiedMultiRectActive {
        if !g_SCWebLlm_EmbedBootstrapped
            g_SCWebLlm_EmbedBootstrapped := true
        ok := SearchCenterWebLlm_EnsureMissingSites(false, h)
        if !ok && SearchCenterWebLlm_HasReadySites()
            ok := true
    } else if !g_SCWebLlm_EmbedBootstrapped {
        navHome := true
        g_SCWebLlm_EmbedBootstrapped := true
        ok := SearchCenterWebLlm_OpenAllSites(navHome)
    } else if navHome {
        ok := SearchCenterWebLlm_OpenAllSites(true)
    } else {
        ok := ScWebLlm_EnsureActiveSiteOpened(false)
        ok := SearchCenterWebLlm_EnsureMissingSites(false) || ok
        if !ok && SearchCenterWebLlm_HasReadySites()
            ok := true
    }
    if ok || SearchCenterWebLlm_HasReadySites() {
        SearchCenterWebLlm_ApplyBounds(h)
        ScWebLlm_ScheduleBoundsRetries()
        ScWebLlm_Trace("bootstrap", true, Map("sites", SearchCenterWebLlm_ListLayoutSiteIds().Length))
        return true
    }
    ScWebLlm_Trace("bootstrap", false, Map("reason", "open_all_failed"))
    return false
}

SearchCenterWebLlm_SubmitToSite(siteId, keyword) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    kw := Trim(String(keyword))
    if (sid = "" || kw = "")
        return false
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible, g_SCWV_Gui
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    forceNav := false
    navUrl := ""
    if InStr(kw, "://") {
        navUrl := kw
        forceNav := true
        ScWebLlm_ClearPendingKeyword(sid)
    } else if RegExMatch(kw, "i)^[\w-]+(\.[\w.-]+)+") {
        navUrl := "https://" . kw
        forceNav := true
        ScWebLlm_ClearPendingKeyword(sid)
    } else if ScWebLlm_NeedsKeywordInject(sid) {
        ScWebLlm_QueuePendingKeyword(sid, kw)
        if !ScWebLlm_SiteReadyForInject(sid) {
            forceNav := true
            navUrl := ScWebLlm_SiteHomeUrl(sid)
        }
    } else {
        ScWebLlm_ClearPendingKeyword(sid)
        forceNav := true
        navUrl := ScWebLlm_ResolveKeywordNavigateUrl(sid, kw)
    }
    ok := SearchCenterWebLlm_OpenSite(sid, forceNav, navUrl)
    SearchCenterWebLlm_ApplyBounds(h)
    return ok
}

SearchCenterWebLlm_NavigateEngine(engine, keyword := "") {
    eng := Trim(String(engine))
    sid := ScWebLlm_EngineToSiteId(eng)
    if (sid = "")
        return false
    global g_SCWebLlm_ActiveSiteId
    g_SCWebLlm_ActiveSiteId := sid
    kw := Trim(String(keyword))
    if (kw = "") {
        global g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
        if !ScWebLlm_ShouldShowWebEmbed()
            return false
        h := ScWebLlm_ResolveEmbedHostHwnd()
        if !h
            return false
        g_SCWebLlm_ParentHwnd := h
        g_SCWebLlm_Visible := true
        ok := SearchCenterWebLlm_OpenSite(sid, true)
        SearchCenterWebLlm_ApplyBounds(h)
        SearchCenterWebLlm_PushChromeState()
        return ok
    }
    ok := SearchCenterWebLlm_SubmitToSite(sid, kw)
    SearchCenterWebLlm_PushChromeState()
    return ok
}

ScWebLlm_ResolveTargetSites(engines := 0) {
    targets := []
    seen := Map()
    src := engines
    if !(IsObject(src) && src.Length > 0) {
        global SearchCenterSelectedEngines
        src := IsObject(SearchCenterSelectedEngines) ? SearchCenterSelectedEngines : []
    }
    if IsObject(src) {
        for eng in src {
            sid := ScWebLlm_EngineToSiteId(eng)
            if (sid = "")
                sid := ScWebLlm_NormalizeSiteId(eng)
            if (sid != "" && !seen.Has(sid)) {
                seen[sid] := true
                targets.Push(sid)
            }
        }
    }
    if (targets.Length = 0) {
        for site in ScWebLlm_EnabledSites()
            targets.Push(site["id"])
    }
    return targets
}

SearchCenterWebLlm_BroadcastSearch(keyword, engines := 0) {
    kw := Trim(String(keyword))
    if (kw = "")
        return false
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    targets := ScWebLlm_ResolveTargetSites(engines)
    ok := false
    idx := 0
    n := Max(1, targets.Length)
    staggerMs := Max(120, Min(220, Floor(1600 / n)))
    for sid in targets {
        delay := idx * staggerMs
        if (delay <= 0) {
            try {
                if SearchCenterWebLlm_SubmitToSite(sid, kw)
                    ok := true
            } catch as e {
                ScWebLlm_Catch(e)
            }
        } else {
            SetTimer(SearchCenterWebLlm_SubmitToSiteDelayed.Bind(sid, kw), -delay)
            ok := true
        }
        idx += 1
    }
    SearchCenterWebLlm_ApplyBounds(h)
    return ok
}

SearchCenterWebLlm_ReloadSites(engines := 0) {
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible, g_SCWebLlm_ContentRectReady
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    if !g_SCWebLlm_ContentRectReady {
        try ScWebLlm_EnsureFallbackContentRect(true)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    targets := ScWebLlm_ResolveTargetSites(engines)
    ok := false
    for sid in targets {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if (rec is Map) && IsObject(rec["wv2"]) {
            try {
                rec["wv2"].Reload()
                ok := true
            } catch as e {
                ScWebLlm_Catch(e)
            }
        } else {
            try {
                if SearchCenterWebLlm_OpenSite(sid, true)
                    ok := true
            } catch as e {
                ScWebLlm_Catch(e)
            }
        }
    }
    SearchCenterWebLlm_ApplyBounds(h)
    SetTimer(SearchCenterWebLlm_PushChromeState, -120)
    return ok
}

SearchCenterWebLlm_ShowReadySites(parentHwnd := 0) {
    h := Integer(parentHwnd)
    if !h
        h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    ok := false
    for sid in SearchCenterWebLlm_ListLayoutSiteIds() {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map) || !rec.Get("ready", false)
            continue
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := true
            catch {
            }
        }
        if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
            try WebView2_NotifyShown(rec["wv2"])
            catch {
            }
        }
        ok := true
    }
    if ok
        SearchCenterWebLlm_ApplyBounds(h)
    return ok
}

SearchCenterWebLlm_RestoreVisibleFromModeSwitch() {
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    global g_SCWebLlm_ContentRectReady
    SearchCenterWebLlm_PrepareForWebModeShow()
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    if !g_SCWebLlm_ContentRectReady {
        try ScWebLlm_EnsureFallbackContentRect(true)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if !g_SCWebLlm_ContentRectReady
        return false
    SearchCenterWebLlm_ApplyBounds(h)
    try SearchCenterWebLlm_EnsureMissingSites(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    try SearchCenterWebLlm_ShowReadySites(h)
    catch as e {
        ScWebLlm_Catch(e)
    }
    ScWebLlm_ScheduleBoundsRetries()
    return SearchCenterWebLlm_HasReadySites()
}

SearchCenterWebLlm_Hide() {
    global g_SCWebLlm_Visible, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRectReady, g_SCWebLlm_SiteHosts
    global g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapWaitCount
    global g_SCWebLlm_WatchdogToken, g_SCWebLlm_BoundsRetryScheduled, g_SCWebLlm_ChildHostBoundsCache, g_SCWebLlm_HostClipCache
    ScWebLlm_EndEmbedFocusGuard()
    g_SCWebLlm_Visible := false
    SearchCenterWebLlm_ClearEmbedRequested()
    g_SCWebLlm_ContentRectReady := false
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_ChildHostBoundsCache := Map()
    g_SCWebLlm_HostClipCache := Map()
    g_SCWebLlm_PendingOpenRequest := 0
    g_SCWebLlm_BootstrapScheduled := false
    g_SCWebLlm_BootstrapInFlight := false
    g_SCWebLlm_BootstrapWaitCount := 0
    g_SCWebLlm_BoundsRetryScheduled := false
    g_SCWebLlm_WatchdogToken := 0
    g_SCWebLlm_LastRaisedHostHwnd := 0
    SearchCenterWebLlm_HideResizeRails()
    ScWebLlm_HideEmbedBackdrop()
    SearchCenterWebLlm_RestoreMainWebView()
    SearchCenterWebLlm_SaveState()
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if IsObject(rec["wv2"]) {
            try WebView2_NotifyHidden(rec["wv2"])
            catch {
            }
        }
        if rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_PositionChildHost(rec["hostHwnd"], 0, 0, 0, 0, false)
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
    }
}

SearchCenterWebLlm_TeardownEmbed(preservePrefs := true) {
    global g_SCWebLlm_Visible, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRectReady, g_SCWebLlm_SiteHosts
    global g_SCWebLlm_UnifiedSuspendGen
    g_SCWebLlm_UnifiedSuspendGen := 0
    global g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapWaitCount
    global g_SCWebLlm_WatchdogToken, g_SCWebLlm_BoundsRetryScheduled, g_SCWebLlm_ChildHostBoundsCache, g_SCWebLlm_HostClipCache
    global g_SCWebLlm_SiteBoundsSig, g_SCWebLlm_EmbedBootstrapped, g_SCWebLlm_LastColFillCss, g_SCWebLlm_LastRaisedHostHwnd
    global g_SCWebLlm_BroadcastSynced, g_SCWebLlm_LayoutSiteIds
    ScWebLlm_EndEmbedFocusGuard()
    g_SCWebLlm_Visible := false
    SearchCenterWebLlm_ClearEmbedRequested()
    g_SCWebLlm_ContentRectReady := false
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_ChildHostBoundsCache := Map()
    g_SCWebLlm_HostClipCache := Map()
    g_SCWebLlm_SiteBoundsSig := Map()
    g_SCWebLlm_LastColFillCss := 0
    g_SCWebLlm_PendingOpenRequest := 0
    g_SCWebLlm_BootstrapScheduled := false
    g_SCWebLlm_BootstrapInFlight := false
    g_SCWebLlm_BootstrapWaitCount := 0
    g_SCWebLlm_BoundsRetryScheduled := false
    g_SCWebLlm_WatchdogToken := 0
    g_SCWebLlm_LastRaisedHostHwnd := 0
    g_SCWebLlm_EmbedBootstrapped := false
    g_SCWebLlm_BroadcastSynced := false
    g_SCWebLlm_LayoutSiteIds := []
    ScWebLlm_ClearUnifiedMultiColumnRects()
    SetTimer(ScWebLlm_BoundsRetryTick, 0)
    SetTimer(ScWebLlm_EmbedBootstrapTick, 0)
    SearchCenterWebLlm_SaveState()
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        SearchCenterWebLlm_DisposeSiteController(sid)
        if IsObject(rec["hostGui"]) {
            try rec["hostGui"].Destroy()
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        rec["hostGui"] := 0
        rec["hostHwnd"] := 0
    }
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    g_SCWebLlm_Ctrl := 0
    g_SCWebLlm_WV2 := 0
    g_SCWebLlm_Ready := false
    g_SCWebLlm_TokenNavCompleted := 0
    SearchCenterWebLlm_HideResizeRails()
    ScWebLlm_HideEmbedBackdrop()
    SearchCenterWebLlm_RestoreMainWebView()
}

SearchCenterWebLlm_Dispose() {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWebLlm_EmbedBootstrapped
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_SiteHosts, g_SCWebLlm_ResizeRails
    global g_SCWebLlm_BroadcastSynced, g_SCWebLlm_LayoutSiteIds
    g_SCWebLlm_BroadcastSynced := false
    g_SCWebLlm_LayoutSiteIds := []
    g_SCWebLlm_Visible := false
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_PendingOpenRequest := 0
    SearchCenterWebLlm_SaveState()
    SearchCenterWebLlm_DisposeActiveController()
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if IsObject(rec["hostGui"]) {
            try rec["hostGui"].Destroy()
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        rec["hostGui"] := 0
        rec["hostHwnd"] := 0
    }
    g_SCWebLlm_SiteHosts := Map()
    SearchCenterWebLlm_HideResizeRails()
    for key, rec in g_SCWebLlm_ResizeRails {
        if (rec is Map) && IsObject(rec["gui"]) {
            try rec["gui"].Destroy()
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
    }
    g_SCWebLlm_ResizeRails := Map()
    global g_SCWebLlm_EdgeRails
    if (g_SCWebLlm_EdgeRails is Map) {
        for key, rec in g_SCWebLlm_EdgeRails {
            if (rec is Map) && IsObject(rec["gui"]) {
                try rec["gui"].Destroy()
                catch as e {
                    ScWebLlm_Catch(e)
                }
            }
        }
    }
    g_SCWebLlm_EdgeRails := Map()
    global g_SCWebLlm_ContentGui, g_SCWebLlm_ContentHostHwnd
    g_SCWebLlm_ContentGui := 0
    g_SCWebLlm_ContentHostHwnd := 0
    g_SCWebLlm_ParentHwnd := 0
    g_SCWebLlm_EmbedBootstrapped := false
}

SearchCenterWebLlm_SelectSite(siteId) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWV_Gui
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ActiveSiteId := sid
    SearchCenterWebLlm_ApplyBounds(h)
    SearchCenterWebLlm_PushChromeState()
    return SearchCenterWebLlm_OpenSite(sid, true)
}

SearchCenterWebLlm_FocusSite(siteId) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    if !ScWebLlm_ScrollEmbedToSite(sid)
        return false
    SearchCenterWebLlm_FocusSiteInput(sid)
    SetTimer(SearchCenterWebLlm_FocusSiteInput.Bind(sid), -260)
    return true
}

SearchCenterWebLlm_NavigateUrl(url, siteId := "") {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible, g_SCWebLlm_WV2, g_SCWV_Gui
    u := Trim(String(url))
    if (u = "")
        return false
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ActiveSiteId := sid
    SearchCenterWebLlm_SyncActiveGlobals()
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if (rec is Map) && rec["ready"] && IsObject(rec["wv2"]) {
        try rec["wv2"].Navigate(u)
        catch as e {
            ScWebLlm_Catch(e)
            return false
        }
        SearchCenterWebLlm_ApplyBounds(h)
        SearchCenterWebLlm_PushChromeState()
        return true
    }
    return SearchCenterWebLlm_OpenSite(sid, true, u)
}

SearchCenterWebLlm_HandleNav(action) {
    act := StrLower(Trim(String(action)))
    if (act = "reload_all") {
        global SearchCenterSelectedEngines
        return SearchCenterWebLlm_ReloadSites(SearchCenterSelectedEngines)
    }
    if !SearchCenterWebLlm_ControllerAlive() {
        global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
        if (act = "home" || act = "reload") {
            sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
            if (sid = "")
                sid := ScWebLlm_DefaultSiteId()
            h := ScWebLlm_ResolveEmbedHostHwnd()
            if !h
                return false
            g_SCWebLlm_ParentHwnd := h
            g_SCWebLlm_Visible := true
            return SearchCenterWebLlm_OpenSite(sid, true)
        }
        return false
    }
    global g_SCWebLlm_ActiveSiteId
    SearchCenterWebLlm_SyncActiveGlobals()
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map) || !IsObject(rec["wv2"])
        return false
    wv2 := rec["wv2"]
    try {
        if (act = "back") {
            if wv2.CanGoBack
                wv2.GoBack()
        } else if (act = "forward") {
            if wv2.CanGoForward
                wv2.GoForward()
        } else if (act = "reload") {
            wv2.Reload()
        } else if (act = "home") {
            home := ScWebLlm_SiteHomeUrl(g_SCWebLlm_ActiveSiteId)
            if (home != "")
                wv2.Navigate(home)
        } else if (act = "copyurl" || act = "copy_url") {
            url := ""
            try url := Trim(String(wv2.Source))
            if (url = "")
                return false
            A_Clipboard := url
            try TrayTip("联网搜索", "已复制当前链接", "Iconi 1")
            catch {
            }
            return true
        } else
            return false
    } catch as e {
        ScWebLlm_Catch(e)
        return false
    }
    SetTimer(SearchCenterWebLlm_PushChromeState, -120)
    return true
}

SearchCenterWebLlm_PrepareForScriptReload() {
    SearchCenterWebLlm_CancelPendingTimers()
    SearchCenterWebLlm_Dispose()
}

SearchCenterWebLlm_CancelPendingTimers() {
    global g_SCWebLlm_UnifiedLayoutBootstrapScheduled, g_SCWebLlm_BoundsRetryScheduled, g_SCWebLlm_BootstrapScheduled
    global g_SCWebLlm_BootstrapInFlight
    g_SCWebLlm_UnifiedLayoutBootstrapScheduled := false
    g_SCWebLlm_BoundsRetryScheduled := false
    g_SCWebLlm_BootstrapScheduled := false
    g_SCWebLlm_BootstrapInFlight := false
    SetTimer(ScWebLlm_BoundsRetryTick, 0)
    SetTimer(ScWebLlm_EmbedBootstrapTick, 0)
    SetTimer(ScWebLlm_EmbedResumeCheck, 0)
    SetTimer(ScWebLlm_ResizeRailDragTick, 0)
    SetTimer(ScWebLlm_ApplyPendingContentRect, 0)
    SetTimer(SearchCenterWebLlm_PushChromeState, 0)
}
