#Requires AutoHotkey v2.0

; HoleWhisperStt — drag audio into black hole → local Whisper STT → show text in hole UI

global g_HoleWhisper_Job := 0

HoleWhisper_GetRootDir() {
    return A_ScriptDir . "\tools\whisper-stt"
}

HoleWhisper_GetPythonExe() {
    return HoleWhisper_GetRootDir() . "\.venv\Scripts\python.exe"
}

HoleWhisper_GetModelDir() {
    return HoleWhisper_GetRootDir() . "\models\small"
}

HoleWhisper_GetTranscribeCli() {
    return HoleWhisper_GetRootDir() . "\transcribe_cli.py"
}

HoleWhisper_IsReady() {
    return FileExist(HoleWhisper_GetPythonExe())
        && FileExist(HoleWhisper_GetTranscribeCli())
        && FileExist(HoleWhisper_GetModelDir() . "\model.bin")
}

HoleWhisper_IsAudioPath(path) {
    ext := ""
    SplitPath path, , , , &extName
    if (extName != "")
        ext := StrLower("." . extName)
    static audioExt := Map(
        ".mp3", true, ".wav", true, ".flac", true, ".aac", true, ".ogg", true,
        ".m4a", true, ".wma", true, ".opus", true, ".webm", true, ".amr", true
    )
    return audioExt.Has(ext)
}

HoleWhisper_CollectAudioPaths(paths) {
    out := []
    if !(paths is Array)
        return out
    for _, p in paths {
        fp := ""
        if (p is Map) {
            fp := p.Has("path") ? Trim(String(p["path"])) : ""
            if (fp = "")
                fp := p.Has("name") ? Trim(String(p["name"])) : ""
        } else {
            fp := Trim(String(p))
        }
        if (fp = "" || !FileExist(fp))
            continue
        if HoleWhisper_IsAudioPath(fp)
            out.Push(fp)
    }
    return out
}

HoleWhisper_JsonStr(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return '"' . s . '"'
}

HoleWhisper_UpdateHoleUI(text, status := "ready") {
    t := HoleWhisper_JsonStr(text)
    st := HoleWhisper_JsonStr(status)
    js := "window.HoleOverlay?.setTranscript?.(" . t . "," . st . ")"
    if (FuncExists("GDHO_RunStarryJS")) {
        try GDHO_RunStarryJS(js)
    } else if FuncExists("GDHO_RunJS") {
        try GDHO_RunJS(js)
    }
}

HoleWhisper_TryRouteAudioFiles(filePaths) {
    audioPaths := HoleWhisper_CollectAudioPaths(filePaths)
    if (audioPaths.Length = 0)
        return false
    ; Only intercept when every dropped path is audio (single or batch).
    allAudio := true
    for _, p in filePaths {
        fp := ""
        if (p is Map) {
            fp := p.Has("path") ? Trim(String(p["path"])) : ""
            if (fp = "")
                fp := p.Has("name") ? Trim(String(p["name"])) : ""
        } else {
            fp := Trim(String(p))
        }
        if (fp != "" && FileExist(fp) && !HoleWhisper_IsAudioPath(fp)) {
            allAudio := false
            break
        }
    }
    if !allAudio
        return false
    HoleWhisper_StartJob(audioPaths)
    return true
}

HoleWhisper_StartJob(audioPaths) {
    global g_HoleWhisper_Job
    if !(audioPaths is Array) || (audioPaths.Length = 0)
        return
    if !HoleWhisper_IsReady() {
        HoleWhisper_UpdateHoleUI("未找到 Whisper 环境或模型。请检查 tools\whisper-stt\models\small", "error")
        try TrayTip("语音转文本", "Whisper 未就绪，请先完成 tools\whisper-stt 安装", "Icon!")
        return
    }
    g_HoleWhisper_Job := Map(
        "paths", audioPaths.Clone(),
        "index", 1,
        "parts", [],
        "running", false
    )
    if FuncExists("GDHO_Show")
        try GDHO_Show("file")
    HoleWhisper_UpdateHoleUI("正在识别语音…", "loading")
    SetTimer(HoleWhisper_ProcessJobStep, -30)
}

HoleWhisper_ProcessJobStep(*) {
    global g_HoleWhisper_Job
    if !(g_HoleWhisper_Job is Map) || g_HoleWhisper_Job.Count = 0
        return
    if g_HoleWhisper_Job["running"]
        return
    idx := Integer(g_HoleWhisper_Job["index"])
    paths := g_HoleWhisper_Job["paths"]
    if !(paths is Array) || (idx > paths.Length) {
        HoleWhisper_FinishJob()
        return
    }
    g_HoleWhisper_Job["running"] := true
    fp := paths[idx]
    name := RegExReplace(fp, ".*\\", "")
    if (paths.Length > 1)
        HoleWhisper_UpdateHoleUI("正在识别 (" . idx . "/" . paths.Length . ")…`n" . name, "loading")
    text := HoleWhisper_TranscribeSync(fp)
    g_HoleWhisper_Job["running"] := false
    if (text != "")
        g_HoleWhisper_Job["parts"].Push(text)
    else
        g_HoleWhisper_Job["parts"].Push("（未能识别：" . name . "）")
    g_HoleWhisper_Job["index"] := idx + 1
    if (g_HoleWhisper_Job["index"] <= paths.Length) {
        SetTimer(HoleWhisper_ProcessJobStep, -20)
        return
    }
    HoleWhisper_FinishJob()
}

HoleWhisper_FinishJob() {
    global g_HoleWhisper_Job
    parts := (g_HoleWhisper_Job is Map && g_HoleWhisper_Job.Has("parts")) ? g_HoleWhisper_Job["parts"] : []
    g_HoleWhisper_Job := 0
    if !(parts is Array) || (parts.Length = 0) {
        HoleWhisper_UpdateHoleUI("未识别到语音内容", "error")
        return
    }
    out := ""
    for i, t in parts {
        if (i > 1)
            out .= "`n`n"
        out .= Trim(String(t))
    }
    HoleWhisper_UpdateHoleUI(out, "ready")
    global GDHO_LAST_DROPPED_TEXT, GDHO_SESSION_TEXT
    try GDHO_LAST_DROPPED_TEXT := out
    try GDHO_SESSION_TEXT := out
}

HoleWhisper_TranscribeSync(audioPath) {
    py := HoleWhisper_GetPythonExe()
    cli := HoleWhisper_GetTranscribeCli()
    modelDir := HoleWhisper_GetModelDir()
    if (!FileExist(py) || !FileExist(cli) || !FileExist(modelDir . "\model.bin"))
        return ""
    outFile := A_Temp . "\nmer_hole_stt_" . A_TickCount . "_" . Random(10000, 99999) . ".txt"
    try FileDelete(outFile)
    cmd := Format(
        '"{1}" "{2}" --input "{3}" --model-dir "{4}" --language zh --output "{5}"',
        py, cli, audioPath, modelDir, outFile
    )
    try {
        sh := ComObject("WScript.Shell")
        exitCode := sh.Run(cmd, 0, true)
    } catch {
        return ""
    }
    text := ""
    if FileExist(outFile) {
        try text := Trim(FileRead(outFile, "UTF-8"))
        catch {
            text := ""
        }
        try FileDelete(outFile)
    }
    if (text = "" && exitCode != 0)
        return ""
    return text
}
