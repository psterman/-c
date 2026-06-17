; VkExecQueue.ahk — dev/CI：vkExec 文件队列（SendMessage 超时时的回退）
;@reference VkExecQueue.d.ahk
#Requires AutoHotkey v2.0
#Include FuncExists.ahk

VkExecQueue_Catch(err) {
    fn := "NmerCatch"
    if !FuncExists(fn)
        return
    try {
        %fn%(A_ThisFunc, err)
    } catch {
    }
}

VkExecQueue_CallIfExists(funcName, args*) {
    name := Trim(String(funcName))
    if (name = "" || !FuncExists(name))
        return ""
    try {
        return (%name%)(args*)
    } catch as err {
        VkExecQueue_Catch(err)
        return ""
    }
}

VkExecQueue_Path() {
    if FuncExists("Nmer_CacheDir") {
        try {
            base := VkExecQueue_CallIfExists("Nmer_CacheDir")
            if (base != "")
                return base . "\ci\vkexec_queue.jsonl"
        } catch {
        }
    }
    return A_ScriptDir . "\Cache\ci\vkexec_queue.jsonl"
}

VkExecQueue_Enqueue(cmdId) {
    cid := Trim(String(cmdId))
    if (cid = "")
        return false
    path := VkExecQueue_Path()
    parent := ""
    try SplitPath(path, , &parent)
    if (parent != "")
        try DirCreate(parent)
    line := '{"cmdId":"' . VkExecQueue_EscapeJson(cid) . '","queuedAt":"' . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . '"}' . "`n"
    try {
        FileAppend(line, path, "UTF-8")
        return true
    } catch {
        return false
    }
}

VkExecQueue_EscapeJson(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    return s
}

VkExecQueue_Drain(*) {
    path := VkExecQueue_Path()
    if !FileExist(path)
        return
    content := ""
    try content := FileRead(path, "UTF-8")
    catch
        return
    content := Trim(content, "`r`n `t")
    if (content = "") {
        try FileDelete(path)
        return
    }
    try FileDelete(path)
    catch {
        try FileAppend("", path, "UTF-8")
    }
    if !FuncExists("VK_Execute")
        return
    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        try {
            doc := VkExecQueue_CallIfExists("Jxon_Load", line)
            if (doc is Map) && doc.Has("cmdId")
                VkExecQueue_CallIfExists("VK_Execute", String(doc["cmdId"]))
        } catch as _e {
            VkExecQueue_Catch(_e)
        }
    }
}

VkExecQueue_Init() {
    static done := false
    if done
        return
    done := true
    SetTimer(VkExecQueue_Drain, 100)
}

VkExecQueue_Init()
