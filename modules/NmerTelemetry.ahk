; NmerTelemetry.ahk — 本地埋点/统计（仅本机 JSON，不上报）
;@reference NmerTelemetry.d.ahk
; 目标：记录谁被用了多少次、最近一次何时成功/失败、失败原因摘要。
#Include FuncExists.ahk
#Include ..\lib\ahk\Jxon.ahk

NmerTelemetry_Catch(err) {
    fn := "NmerCatch"
    if !FuncExists(fn)
        return
    try {
        %fn%(A_ThisFunc, err)
    } catch {
    }
}

NmerTelemetry_CallIfExists(funcName, args*) {
    name := Trim(String(funcName))
    if (name = "" || !FuncExists(name))
        return ""
    try {
        return (%name%)(args*)
    } catch as err {
        NmerTelemetry_Catch(err)
        return ""
    }
}

global g_NmerTelemetry_LastState := Map()
global g_NmerTelemetry_FunnelState := Map()
global g_NmerTelemetry_FunnelGuard := false
global g_NmerTelemetry_MirrorGuard := false
global g_NmerTelemetry_DeferWriteDepth := 0
global g_NmerTelemetry_WriteBusy := false
global g_NmerTelemetry_WritePending := false
global g_NmerTelemetry_WriteScheduled := false

Nmer_Telemetry_WriteDeferred(*) {
    global g_NmerTelemetry_WritePending
    g_NmerTelemetry_WritePending := false
    Nmer_Telemetry_Write()
}

Nmer_Telemetry_ScheduleWrite(snap := 0) {
    global g_NmerTelemetry_LastState, g_NmerTelemetry_WriteScheduled, g_NmerTelemetry_DeferWriteDepth
    if (g_NmerTelemetry_DeferWriteDepth > 0)
        return
    if (snap is Map) && snap.Count
        g_NmerTelemetry_LastState := snap
    if g_NmerTelemetry_WriteScheduled
        return
    g_NmerTelemetry_WriteScheduled := true
    try SetTimer(Nmer_Telemetry_FlushScheduledWrite, -280)
    catch as _e {
        NmerTelemetry_Catch(_e)
        g_NmerTelemetry_WriteScheduled := false
        try Nmer_Telemetry_Write(snap)
        catch as _e2 {
            NmerTelemetry_Catch(_e2)
        }
    }
}

Nmer_Telemetry_FlushScheduledWrite(*) {
    global g_NmerTelemetry_WriteScheduled, g_NmerTelemetry_LastState
    g_NmerTelemetry_WriteScheduled := false
    snap := (g_NmerTelemetry_LastState is Map) ? g_NmerTelemetry_LastState : Map()
    try Nmer_Telemetry_Write(snap)
    catch as _e {
        NmerTelemetry_Catch(_e)
    }
}

Nmer_Telemetry_BeginDeferWrite() {
    global g_NmerTelemetry_DeferWriteDepth
    g_NmerTelemetry_DeferWriteDepth += 1
}

Nmer_Telemetry_EndDeferWrite(flush := true) {
    global g_NmerTelemetry_DeferWriteDepth
    g_NmerTelemetry_DeferWriteDepth := Max(0, g_NmerTelemetry_DeferWriteDepth - 1)
    if flush && g_NmerTelemetry_DeferWriteDepth = 0
        Nmer_Telemetry_ScheduleWrite()
}

Nmer_Telemetry_SanitizeMeta(scope, action, meta := 0) {
    sc := StrLower(Trim(String(scope)))
    act := StrLower(Trim(String(action)))
    out := Map()
    if (sc = "surface") {
        if (meta is Map) {
            for key in ["surfaceId", "requestId", "action", "source", "reason", "triggerSource", "navigateTab", "mode"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "cmdpal_agent") {
        if (meta is Map) {
            for key in ["source", "event", "kind"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "cmdpal") {
        if (meta is Map) {
            for key in ["durationMs", "generation", "resultCount", "layoutMode", "sessionId"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "cmd") {
        if (meta is Map) {
            for key in ["source", "cmdId", "status", "reason"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "search") {
        if (meta is Map) {
            for key in ["source", "category", "scope"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "settings") {
        if (meta is Map) {
            for key in ["tab", "source"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "migration") {
        if (meta is Map) {
            for key in ["source", "files", "ok"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "llm") {
        if (meta is Map) {
            for key in ["provider", "baseUrl", "endpoint", "elapsedMs", "status", "source", "cmdId"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "diagnostics") {
        if (meta is Map) {
            for key in ["files", "trigger", "source", "lines"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "studio") {
        if (meta is Map) {
            if meta.Has("needChatExport")
                out["needChatExport"] := meta["needChatExport"]
        }
        return out
    }
    if (sc = "health") {
        if (meta is Map) {
            if meta.Has("trigger")
                out["trigger"] := meta["trigger"]
        }
        return out
    }
    if (sc = "vk") {
        if (meta is Map) {
            for key in ["cmdId", "policy", "sceneId", "source"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    if (sc = "niuma_chat") {
        if (meta is Map) {
            for key in ["source", "status", "elapsedMs"] {
                if meta.Has(key)
                    out[String(key)] := meta[key]
            }
        }
        return out
    }
    return out
}

Nmer_TelemetryPath(*) {
    p := NmerTelemetry_CallIfExists("Nmer_DebugPath", "nmer_telemetry.json")
    if (p != "")
        return p
    return A_ScriptDir . "\Cache\debug\nmer_telemetry.json"
}

Nmer_Telemetry_Read(*) {
    path := Nmer_TelemetryPath()
    if !FileExist(path)
        return Map()
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return Map()
        doc := NmerTelemetry_CallIfExists("Jxon_Load", raw)
        if (doc is Map)
            return doc
    } catch as _e {
        NmerTelemetry_Catch(_e)
    }
    return Map()
}

Nmer_Telemetry_Snapshot(*) {
    global g_NmerTelemetry_LastState
    if (g_NmerTelemetry_LastState is Map) && g_NmerTelemetry_LastState.Count
        return g_NmerTelemetry_LastState
    return Nmer_Telemetry_Read()
}

Nmer_Telemetry_Write(snap := 0) {
    global g_NmerTelemetry_WriteBusy, g_NmerTelemetry_WritePending
    if g_NmerTelemetry_WriteBusy {
        g_NmerTelemetry_WritePending := true
        return false
    }
    g_NmerTelemetry_WriteBusy := true
    ok := false
    try {
        if !(snap is Map) || snap.Count = 0 {
            snap := Nmer_Telemetry_Snapshot()
            if !(snap is Map) || snap.Count = 0
                return false
        }
        path := Nmer_TelemetryPath()
        dir := ""
        if RegExMatch(path, "^(.*)\\[^\\]+$", &m)
            dir := m[1]
        if (dir != "") {
            try DirCreate(dir)
            catch as _e {
                NmerTelemetry_Catch(_e)
            }
        }
        json := ""
        try {
            if FuncExists("Jxon_Dump")
                json := Jxon_Dump(snap)
            else
                return false
        } catch as _e2 {
            NmerTelemetry_Catch(_e2)
            return false
        }
        if (json = "")
            return false
        tmpPath := path . ".tmp"
        try FileDelete(tmpPath)
        catch as _e3 {
            NmerTelemetry_Catch(_e3)
        }
        try {
            f := FileOpen(tmpPath, "w", "UTF-8")
            if !IsObject(f)
                return false
            f.Write(json)
            f.Close()
            try FileMove(tmpPath, path, true)
            catch as _eMove {
                NmerTelemetry_Catch(_eMove)
                try FileDelete(path)
                catch {
                }
                try FileMove(tmpPath, path, true)
                catch as _eMove2 {
                    NmerTelemetry_Catch(_eMove2)
                    return false
                }
            }
            ok := true
        } catch as _e4 {
            NmerTelemetry_Catch(_e4)
            ok := false
            try FileDelete(tmpPath)
            catch {
            }
        }
    } finally {
        g_NmerTelemetry_WriteBusy := false
        if g_NmerTelemetry_WritePending {
            g_NmerTelemetry_WritePending := false
            try SetTimer(Nmer_Telemetry_WriteDeferred, -80)
            catch as _e5 {
                NmerTelemetry_Catch(_e5)
            }
        }
    }
    return ok
}

Nmer_Telemetry_MarkSurfaceOpen(surfaceName, meta := 0) {
    surface := StrLower(Trim(String(surfaceName)))
    if (surface = "")
        return
    global g_NmerTelemetry_FunnelState
    if !(g_NmerTelemetry_FunnelState is Map)
        g_NmerTelemetry_FunnelState := Map()
    g_NmerTelemetry_FunnelState[surface] := false
    try Nmer_Telemetry_Record("surface", surface . "_open", true, meta)
}

Nmer_Telemetry_MarkSurfaceAction(surfaceName, action := "", meta := 0) {
    surface := StrLower(Trim(String(surfaceName)))
    if (surface = "")
        return
    global g_NmerTelemetry_FunnelState
    if !(g_NmerTelemetry_FunnelState is Map)
        g_NmerTelemetry_FunnelState := Map()
    if !g_NmerTelemetry_FunnelState.Has(surface)
        g_NmerTelemetry_FunnelState[surface] := false
    if !!g_NmerTelemetry_FunnelState[surface]
        return
    m := Map()
    if (meta is Map) {
        for k, v in meta
            m[String(k)] := v
    }
    act := StrLower(Trim(String(action)))
    if (act != "")
        m["action"] := act
    g_NmerTelemetry_FunnelState[surface] := true
    try Nmer_Telemetry_Record("surface", surface . "_first_action", true, m)
}

Nmer_Telemetry_MarkSurfaceClose(surfaceName, meta := 0) {
    surface := StrLower(Trim(String(surfaceName)))
    if (surface = "")
        return
    acted := false
    global g_NmerTelemetry_FunnelState
    if !(g_NmerTelemetry_FunnelState is Map)
        g_NmerTelemetry_FunnelState := Map()
    if g_NmerTelemetry_FunnelState.Has(surface)
        acted := !!g_NmerTelemetry_FunnelState[surface]
    try Nmer_Telemetry_Record("surface", surface . "_close", true, meta)
    if !acted
        try Nmer_Telemetry_Record("surface", surface . "_open_without_action", true, meta)
    if g_NmerTelemetry_FunnelState.Has(surface)
        g_NmerTelemetry_FunnelState.Delete(surface)
}

Nmer_Telemetry_MaybeMarkFirstAction(scope, action, ok, meta := 0) {
    if !ok
        return
    sc := StrLower(Trim(String(scope)))
    act := StrLower(Trim(String(action)))
    src := ""
    if (meta is Map) && meta.Has("source")
        src := StrLower(Trim(String(meta["source"])))
    if (sc = "cmd" && InStr(src, "_cp_")) {
        Nmer_Telemetry_MarkSurfaceAction("clipboard_panel", act, Map("source", src))
        return
    }
    if (sc = "cmd" && src = "command_palette") {
        Nmer_Telemetry_MarkSurfaceAction("command_palette", act, Map("source", src))
        return
    }
    if (sc = "cmdpal" && (act = "query" || act = "submit" || act = "results")) {
        Nmer_Telemetry_MarkSurfaceAction("command_palette", act, Map("source", src))
        return
    }
    if (sc = "search" && act = "search_center_query") {
        Nmer_Telemetry_MarkSurfaceAction("search_center", act, Map("source", src))
        return
    }
    if (sc = "settings" && (InStr(act, "save") || InStr(act, "import") || InStr(act, "export") || InStr(act, "reset"))) {
        Nmer_Telemetry_MarkSurfaceAction("config_webview", act, Map("source", src))
        return
    }
    if (sc = "cmd") {
        srcLower := StrLower(src)
        if (InStr(srcLower, "chordpad") || InStr(srcLower, "chord_pad")) {
            Nmer_Telemetry_MarkSurfaceAction("chord_pad", act, Map("source", src))
            return
        }
    }
    if (sc = "niuma_chat" && (act = "send" || act = "send_ok" || act = "send_fail")) {
        Nmer_Telemetry_MarkSurfaceAction("floating_toolbar", act, Map("source", src))
        return
    }
    if (sc = "surface" && act = "floating_toolbar_mode") {
        Nmer_Telemetry_MarkSurfaceAction("floating_toolbar", act, Map("source", src))
        return
    }
}

Nmer_Telemetry_MirrorUnifiedEvents(scope, action, ok, meta := 0) {
    sc := StrLower(Trim(String(scope)))
    act := StrLower(Trim(String(action)))
    if (sc = "cmd" && act != "") {
        if (SubStr(act, 1, 4) != "cmd_") {
            m := Map("cmdId", act)
            if (meta is Map) {
                if meta.Has("source")
                    m["source"] := meta["source"]
            }
            try {
                Nmer_Telemetry_Record("cmd", "cmd_execute", true, m)
                Nmer_Telemetry_Record("cmd", ok ? "cmd_success" : "cmd_fail", ok, m)
            } catch as _e {
                NmerTelemetry_Catch(_e)
            }
        }
        return
    }
    if (sc = "niuma_chat") {
        m := Map()
        if (meta is Map) {
            for k, v in meta
                m[String(k)] := v
        }
        try {
            if (act = "send")
                Nmer_Telemetry_Record("llm", "request_start", true, m)
            else if (act = "send_ok")
                Nmer_Telemetry_Record("llm", "request_done", true, m)
            else if (act = "send_fail")
                Nmer_Telemetry_Record("llm", "request_fail", false, m)
        } catch as _e {
            NmerTelemetry_Catch(_e)
        }
    }
}

Nmer_Telemetry_Record(scope, action, ok := true, meta := 0) {
    sc := StrLower(Trim(String(scope)))
    act := StrLower(Trim(String(action)))
    if (sc = "")
        sc := "general"
    if (act = "")
        act := "event"
    global g_NmerTelemetry_FunnelGuard
    if !g_NmerTelemetry_FunnelGuard {
        g_NmerTelemetry_FunnelGuard := true
        try Nmer_Telemetry_MaybeMarkFirstAction(sc, act, !!ok, meta)
        catch as _e {
            NmerTelemetry_Catch(_e)
        }
        g_NmerTelemetry_FunnelGuard := false
    }
    global g_NmerTelemetry_MirrorGuard
    if !g_NmerTelemetry_MirrorGuard {
        g_NmerTelemetry_MirrorGuard := true
        try Nmer_Telemetry_MirrorUnifiedEvents(sc, act, !!ok, meta)
        catch as _e {
            NmerTelemetry_Catch(_e)
        }
        g_NmerTelemetry_MirrorGuard := false
    }
    snap := Nmer_Telemetry_Snapshot()
    if !(snap is Map)
        snap := Map()
    if !snap.Has("scopes")
        snap["scopes"] := Map()
    scopes := snap["scopes"]
    if !(scopes is Map) {
        scopes := Map()
        snap["scopes"] := scopes
    }
    if !scopes.Has(sc)
        scopes[sc] := Map("total", 0, "ok", 0, "fail", 0, "actions", Map())
    bucket := scopes[sc]
    if !(bucket is Map)
        bucket := Map("total", 0, "ok", 0, "fail", 0, "actions", Map())
    if !bucket.Has("actions") || !(bucket["actions"] is Map)
        bucket["actions"] := Map()
    actions := bucket["actions"]
    if !actions.Has(act)
        actions[act] := Map("count", 0, "ok", 0, "fail", 0, "lastAt", "", "lastOk", true, "lastError", "")
    row := actions[act]
    row["count"] := Integer(row.Get("count", 0)) + 1
    bucket["total"] := Integer(bucket.Get("total", 0)) + 1
    if ok {
        row["ok"] := Integer(row.Get("ok", 0)) + 1
        bucket["ok"] := Integer(bucket.Get("ok", 0)) + 1
    } else {
        row["fail"] := Integer(row.Get("fail", 0)) + 1
        bucket["fail"] := Integer(bucket.Get("fail", 0)) + 1
    }
    row["lastAt"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    row["lastOk"] := !!ok
    errText := ""
    if (meta is Map) && meta.Has("error")
        errText := Trim(String(meta["error"]))
    meta := Nmer_Telemetry_SanitizeMeta(sc, act, meta)
    row["lastError"] := errText
    if (meta is Map) && meta.Count
        row["lastMeta"] := meta
    bucket["lastAt"] := row["lastAt"]
    bucket["lastOk"] := row["lastOk"]
    if (errText != "")
        bucket["lastError"] := errText
    scopes[sc] := bucket
    snap["scopes"] := scopes
    snap["generatedAt"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    global g_NmerTelemetry_LastState
    global g_NmerTelemetry_DeferWriteDepth
    g_NmerTelemetry_LastState := snap
    if (g_NmerTelemetry_DeferWriteDepth <= 0)
        Nmer_Telemetry_ScheduleWrite(snap)
    return snap
}

Nmer_Telemetry_BuildSummary(limit := 8) {
    snap := Nmer_Telemetry_Snapshot()
    if !(snap is Map)
        snap := Map()
    scopes := snap.Has("scopes") && (snap["scopes"] is Map) ? snap["scopes"] : Map()
    rows := []
    actionRows := []
    for scope, bucket in scopes {
        if !(bucket is Map)
            continue
        acts := bucket.Has("actions") && (bucket["actions"] is Map) ? bucket["actions"] : Map()
        for act, row in acts {
            if !(row is Map)
                continue
            actionRows.Push(Map(
                "scope", String(scope),
                "action", String(act),
                "count", Integer(row.Get("count", 0)),
                "ok", Integer(row.Get("ok", 0)),
                "fail", Integer(row.Get("fail", 0)),
                "lastAt", String(row.Get("lastAt", "")),
                "lastOk", !!row.Get("lastOk", true),
                "lastError", String(row.Get("lastError", "")))
            )
        }
        rows.Push(Map(
            "scope", String(scope),
            "total", Integer(bucket.Get("total", 0)),
            "ok", Integer(bucket.Get("ok", 0)),
            "fail", Integer(bucket.Get("fail", 0)),
            "lastAt", String(bucket.Get("lastAt", "")),
            "lastOk", !!bucket.Get("lastOk", true),
            "lastError", String(bucket.Get("lastError", "")))
        )
    }
    rows := Nmer_Telemetry_SortRows(rows)
    actionRows := Nmer_Telemetry_SortActionRows(actionRows)
    top := []
    maxN := Max(1, Integer(limit))
    Loop Min(maxN, rows.Length) {
        r := rows[A_Index]
        top.Push(r)
    }
    topActions := []
    Loop Min(maxN, actionRows.Length) {
        r := actionRows[A_Index]
        topActions.Push(r)
    }
    recentFail := ""
    for _, r in rows {
        if !r["lastOk"] && r["lastError"] != "" {
            recentFail := r["scope"] . ": " . r["lastError"]
            break
        }
    }
    return Map(
        "generatedAt", String(snap.Get("generatedAt", "")),
        "totalScopes", rows.Length,
        "topScopes", top,
        "topActions", topActions,
        "recentFail", recentFail,
        "hasData", rows.Length > 0
    )
}

Nmer_Telemetry_SortRows(rows) {
    if !(rows is Array) || rows.Length = 0
        return rows
    out := []
    for r in rows
        out.Push(r)
    loop out.Length - 1 {
        swapped := false
        loop out.Length - A_Index {
            i := A_Index
            a := out[i], b := out[i + 1]
            ta := Integer(a.Get("total", 0)), tb := Integer(b.Get("total", 0))
            if (tb > ta) {
                out[i] := b
                out[i + 1] := a
                swapped := true
            }
        }
        if !swapped
            break
    }
    return out
}

; CI/E2E：一次性补齐 required 清单（dev 脚本 telemetry_required_fill 调用）
Nmer_Telemetry_CiRequiredFill() {
    meta := Map("source", "telemetry_auto_trigger")
    Nmer_Telemetry_BeginDeferWrite()
    try {
        for sid in ["config_webview", "search_center", "ai_workbench", "cli_workbench", "clipboard_panel", "command_palette", "prompt_quick_pad", "chord_pad"] {
            try Nmer_Telemetry_Record("surface", sid . "_open", true, meta)
            catch as _e1
                NmerTelemetry_Catch(_e1)
            try Nmer_Telemetry_Record("surface", sid . "_close", true, meta)
            catch as _e2
                NmerTelemetry_Catch(_e2)
        }
        try Nmer_Telemetry_Record("cmd", "ch_c", true, meta)
        catch as _e3
            NmerTelemetry_Catch(_e3)
        try Nmer_Telemetry_Record("niuma_chat", "send", true, meta)
        catch as _e4
            NmerTelemetry_Catch(_e4)
        for act in ["export", "preview", "import"] {
            try Nmer_Telemetry_Record("migration", act, true, meta)
            catch as _e5
                NmerTelemetry_Catch(_e5)
        }
        try Nmer_Telemetry_Record("diagnostics", "export_bundle", true, meta)
        catch as _e6
            NmerTelemetry_Catch(_e6)
        try Nmer_Telemetry_Record("diagnostics", "copy_trace_clipboard", true, Map("source", "telemetry_auto_trigger", "lines", 80))
        catch as _e7
            NmerTelemetry_Catch(_e7)
    } finally {
        Nmer_Telemetry_EndDeferWrite(true)
    }
}

Nmer_Telemetry_SortActionRows(rows) {
    if !(rows is Array) || rows.Length = 0
        return rows
    out := []
    for r in rows
        out.Push(r)
    loop out.Length - 1 {
        swapped := false
        loop out.Length - A_Index {
            i := A_Index
            a := out[i], b := out[i + 1]
            ca := Integer(a.Get("count", 0)), cb := Integer(b.Get("count", 0))
            if (cb > ca) {
                out[i] := b
                out[i + 1] := a
                swapped := true
            }
        }
        if !swapped
            break
    }
    return out
}
