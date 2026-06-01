#Requires AutoHotkey v2.0

; WailsWhisperVoice — CapsLock 双击拉起输入框后的本地 Whisper 语音输入

global WailsWhisperEnabled := true
global g_WailsWhisper_Recording := false
global g_WailsWhisper_RecordPid := 0
global g_WailsWhisper_WavPath := ""
global g_WailsWhisper_StopFlagPath := ""
global g_WailsWhisper_Status := "idle"  ; idle | recording | transcribing
global g_WailsWhisper_CmdWatchStarted := false
global g_WailsWhisper_SttOut := ""
global g_WailsWhisper_SttWav := ""
global g_WailsWhisper_TranscribeDeadline := 0

_WailsWhisper_H(name, args*) {
    ; 间接调用宿主函数，避免裸名被当成未赋值局部变量，也避免 Func().Call 的 Invalid base
    try {
        if (args.Length = 0)
            return %name%()
        if (args.Length = 1)
            return %name%(args[1])
        if (args.Length = 2)
            return %name%(args[1], args[2])
        if (args.Length = 3)
            return %name%(args[1], args[2], args[3])
        if (args.Length = 4)
            return %name%(args[1], args[2], args[3], args[4])
        if (args.Length = 5)
            return %name%(args[1], args[2], args[3], args[4], args[5])
        throw Error("too many args for _WailsWhisper_H")
    } catch as e {
        throw e
    }
}

WailsWhisper_GetRecordCli() {
    return WailsWhisper_GetWhisperRoot() . "\record_cli.py"
}

WailsWhisper_GetPythonExe() {
    return WailsWhisper_GetWhisperRoot() . "\.venv\Scripts\python.exe"
}

WailsWhisper_GetRecordLauncher() {
    return WailsWhisper_GetWhisperRoot() . "\run_record.cmd"
}

WailsWhisper_ToShortPath(path) {
    buf := Buffer(32768, 0)
    len := DllCall("GetShortPathNameW", "wstr", path, "ptr", buf, "uint", 32767, "uint")
    return len ? StrGet(buf) : path
}

WailsWhisper_FindRecordPythonPid(root := "") {
    if (root = "")
        root := WailsWhisper_GetWhisperRoot()
    targetExe := StrLower(root . "\.venv\Scripts\python.exe")
    found := 0
    try {
        for p in ComObjGet("winmgmts:").ExecQuery("Select ProcessId,ExecutablePath,CommandLine from Win32_Process where Name='python.exe'") {
            try {
                if (StrLower(p.ExecutablePath) != targetExe)
                    continue
                cl := String(p.CommandLine)
                if !InStr(cl, "record_cli.py")
                    continue
                found := p.ProcessId
                break
            } catch {
            }
        }
    } catch {
    }
    return found
}

WailsWhisper_SpawnRecordProcess(wavPath, stopPath) {
    root := WailsWhisper_GetWhisperRoot()
    launcher := WailsWhisper_GetRecordLauncher()
    if !FileExist(launcher)
        return {ok: false, pid: 0, err: "缺少 run_record.cmd"}
    if !FileExist(WailsWhisper_GetPythonExe())
        return {ok: false, pid: 0, err: "未安装 Python：tools\whisper-stt\.venv"}
    cmd := Format('"{1}" --output "{2}" --stop-file "{3}"', launcher, wavPath, stopPath)
    ff := WailsWhisper_FindFfmpeg()
    if (ff != "ffmpeg" && FileExist(ff))
        try EnvSet("FFMPEG_PATH", ff)
    pid := 0
    try {
        sh := ComObject("WScript.Shell")
        sh.CurrentDirectory := root
        sh.Run(cmd, 0, false)
        Sleep(350)
        pid := WailsWhisper_FindRecordPythonPid(root)
    } catch as e {
        return {ok: false, pid: 0, err: e.Message}
    }
    if !pid {
        try {
            shortCmd := Format('"{1}" --output "{2}" --stop-file "{3}"'
                , WailsWhisper_ToShortPath(launcher), wavPath, stopPath)
            Run(A_ComSpec . ' /c ' . shortCmd, WailsWhisper_ToShortPath(root), "Hide", &pid)
            Sleep(300)
            if !pid || !ProcessExist(pid)
                pid := WailsWhisper_FindRecordPythonPid(root)
        } catch {
            pid := 0
        }
    }
    if !pid || !ProcessExist(pid) {
        err := "无法启动录音（中文路径下 Run 可能失败，已尝试 Shell 启动）"
        logPath := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir) . "\Cache\wails_record_err.log"
        if FileExist(logPath) {
            try err .= "`n" . Trim(FileRead(logPath, "UTF-8"))
        }
        return {ok: false, pid: 0, err: err}
    }
    return {ok: true, pid: pid, err: ""}
}

WailsWhisper_FindFfmpeg() {
    if FileExist(Nmer_LibRuntimePath("ffmpeg.exe"))
        return Nmer_LibRuntimePath("ffmpeg.exe")
    try {
        if (p := EnvGet("FFMPEG_PATH")) && FileExist(p)
            return p
    }
    return "ffmpeg"
}

WailsWhisper_HasFfmpeg() {
    p := WailsWhisper_FindFfmpeg()
    if (p != "ffmpeg" && FileExist(p))
        return true
    try {
        shell := ComObject("WScript.Shell")
        ec := shell.Run('cmd /c ffmpeg -version >nul 2>&1', 0, true)
        return (ec = 0)
    } catch {
        return false
    }
}

WailsWhisper_GetWhisperRoot() {
    base := (IsSet(MainScriptDir) && MainScriptDir != "") ? MainScriptDir : A_ScriptDir
    return base . "\tools\whisper-stt"
}

WailsWhisper_GetNotReadyReason() {
    if !WailsWhisperEnabled
        return "语音输入已禁用"
    root := WailsWhisper_GetWhisperRoot()
    py := root . "\.venv\Scripts\python.exe"
    if !FileExist(py)
        return "未安装 Python：tools\whisper-stt\.venv\Scripts\python.exe"
    if !FileExist(root . "\record_cli.py")
        return "缺少 tools\whisper-stt\record_cli.py"
    if !FileExist(root . "\transcribe_cli.py")
        return "缺少 tools\whisper-stt\transcribe_cli.py"
    if !WailsWhisper_HasFfmpeg()
        return "未找到 ffmpeg，请放入 lib\\runtime\\ffmpeg.exe 或安装到 PATH"
    return ""
}

WailsWhisper_IsReady() {
    return (WailsWhisper_GetNotReadyReason() = "")
}

WailsWhisper_JsonStr(s) {
    if FuncExists("HoleWhisper_JsonStr")
        return _WailsWhisper_H("HoleWhisper_JsonStr", s)
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return '"' . s . '"'
}

WailsWhisper_GetCacheDir() {
    base := (IsSet(MainScriptDir) && MainScriptDir != "") ? MainScriptDir : A_ScriptDir
    return base . "\Cache"
}

WailsWhisper_GetStatusFile() {
    return WailsWhisper_GetCacheDir() . "\wails_voice_status.json"
}

WailsWhisper_GetCmdFile() {
    return WailsWhisper_GetCacheDir() . "\wails_voice_cmd.txt"
}

WailsWhisper_HasLocalModel() {
    return FileExist(WailsWhisper_GetWhisperRoot() . "\models\small\model.bin")
}

WailsWhisper_EnsureInputVisible() {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_Show"))
        SetTimer(() => CommandPalette_Show(), -50)
    else if FuncExists("ActivateWailsInputBox")
        SetTimer(() => ActivateWailsInputBox(), -50)
    else if FuncExists("WailsInput_FocusWebInput")
        SetTimer(WailsInput_FocusWebInput, -80)
}

WailsWhisper_WaitForWav(wavPath, timeoutMs := 10000) {
    if (wavPath = "")
        return false
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        if FileExist(wavPath) {
            try {
                if (FileGetSize(wavPath) > 3200)
                    return true
            } catch {
            }
        }
        Sleep(120)
    }
    return false
}

WailsWhisper_EscapeJson(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return s
}

WailsWhisper_PublishStatus(text, status := "ready") {
    global g_WailsWhisper_Status
    st := Trim(String(status))
    if (st = "recording")
        st := "listening"
    if (st = "transcribing")
        st := "loading"
    g_WailsWhisper_Status := st
    msg := WailsWhisper_EscapeJson(text)
    json := '{"status":"' . st . '","message":"' . msg . '"}'
    path := WailsWhisper_GetStatusFile()
    try DirCreate(WailsWhisper_GetCacheDir())
    try FileDelete(path)
    try FileAppend(json, path, "UTF-8")
}

WailsWhisper_ShowStatus(text, status := "ready") {
    WailsWhisper_PublishStatus(text, status)
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_PushStatus")) {
        if FuncExists("CommandPalette_IsVisible") && CommandPalette_IsVisible()
            CommandPalette_PushStatus(text, status)
    }
    WailsWhisper_EnsureInputVisible()
    t := WailsWhisper_JsonStr(text)
    st := WailsWhisper_JsonStr(status)
    js := "window.nmerVoice?.setStatus?.(" . t . "," . st . ")"
    if !WailsWhisper_RunJsInInputHost(js) {
        if (status = "error" || status = "idle")
            try TrayTip("语音输入", text, status = "error" ? "Icon!" : "Iconi")
    }
}

WailsWhisper_EnsureCmdWatcher() {
    global g_WailsWhisper_CmdWatchStarted
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView)
        return
    if g_WailsWhisper_CmdWatchStarted
        return
    g_WailsWhisper_CmdWatchStarted := true
    try DirCreate(WailsWhisper_GetCacheDir())
    SetTimer(WailsWhisper_PollVoiceCmd, 200)
}

WailsWhisper_PollVoiceCmd(*) {
    path := WailsWhisper_GetCmdFile()
    if !FileExist(path)
        return
    cmd := ""
    try cmd := StrLower(Trim(FileRead(path, "UTF-8")))
    try FileDelete(path)
    if (cmd = "")
        return
    if (cmd = "toggle") {
        if WailsWhisper_IsRecording()
            SetTimer(WailsWhisper_StopAndTranscribe, -30)
        else {
            WailsWhisper_EnsureInputVisible()
            WailsWhisper_StartRecording()
        }
    } else if (cmd = "start") {
        WailsWhisper_EnsureInputVisible()
        WailsWhisper_StartRecording()
    } else if (cmd = "stop") {
        SetTimer(WailsWhisper_StopAndTranscribe, -30)
    }
}

WailsWhisper_RunJsInInputHost(js) {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_ExecScript")) {
        if FuncExists("CommandPalette_IsVisible") && CommandPalette_IsVisible() {
            if CommandPalette_ExecScript(js)
                return true
        }
    }
    global WailsInputWindowTitle, WailsInputWindowExe, WailsInputTitleKeywords
    queries := []
    if (Trim(WailsInputWindowTitle) != "")
        queries.Push(Trim(WailsInputWindowTitle))
    if (Trim(WailsInputWindowExe) != "")
        queries.Push("ahk_exe " . Trim(WailsInputWindowExe))
    queries.Push("ahk_exe nmer-wails-input-dev.exe")
    queries.Push("ahk_exe wails-toolbar-app.exe")
    for _, q in queries {
        if !WinExist(q)
            continue
        if FuncExists("SCWV_ExecScript") {
            try {
                _WailsWhisper_H("SCWV_ExecScript", q, js)
                return true
            } catch {
            }
        }
        if FuncExists("WebView2_ExecuteScript") {
            try {
                _WailsWhisper_H("WebView2_ExecuteScript", q, js)
                return true
            } catch {
            }
        }
    }
    return false
}

WailsWhisper_GetActiveInputHwnd() {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_GetGuiHwnd")) {
        h := CommandPalette_GetGuiHwnd()
        if h
            return h
    }
    global WailsInputWindowTitle, WailsInputWindowExe, WailsInputTitleKeywords
    fg := WinGetID("A")
    if !fg
        return 0
    title := ""
    exe := ""
    try title := WinGetTitle("ahk_id " . fg)
    try exe := WinGetProcessName("ahk_id " . fg)
    titleLower := StrLower(title)
    exeLower := StrLower(exe)
    for kw in StrSplit(String(WailsInputTitleKeywords), "|") {
        k := Trim(kw)
        if (k != "" && InStr(titleLower, StrLower(k)))
            return fg
    }
    for name in ["nmer-wails-input-dev.exe", "wails-toolbar-app.exe", "chrome.exe", "msedge.exe"] {
        if (exeLower = name && (InStr(titleLower, "nmer") || InStr(titleLower, "wails") || InStr(titleLower, "command bar")))
            return fg
    }
    return 0
}

WailsWhisper_FocusInput() {
    hwnd := WailsWhisper_GetActiveInputHwnd()
    if !hwnd
        return false
    try {
        if FuncExists("LegacyGuard_RequestFocus")
            _WailsWhisper_H("LegacyGuard_RequestFocus", "WailsWhisperVoice", "ahk_id " . hwnd, 80, "voice_input")
        else
            WinActivate("ahk_id " . hwnd)
        Sleep(80)
        return true
    } catch {
        return false
    }
}

WailsWhisper_FillInputText(text) {
    t := Trim(String(text))
    if (t = "")
        return false
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_SetInputText")) {
        if FuncExists("CommandPalette_Show")
            CommandPalette_Show()
        CommandPalette_SetInputText(t)
        return true
    }
    js := "window.nmerVoice?.setInputText?.(" . WailsWhisper_JsonStr(t) . ")"
    if WailsWhisper_RunJsInInputHost(js)
        return true
    WailsWhisper_FocusInput()
    Sleep(60)
    clipBak := ""
    try clipBak := A_Clipboard
    try {
        A_Clipboard := t
        if !ClipWait(1) {
            SendText(t)
            return true
        }
        Send("^v")
        Sleep(120)
        return true
    } catch {
        try SendText(t)
        return true
    } finally {
        if (clipBak != "")
            try A_Clipboard := clipBak
    }
}

WailsWhisper_StartRecording() {
    global g_WailsWhisper_Recording, g_WailsWhisper_RecordPid, g_WailsWhisper_WavPath, g_WailsWhisper_StopFlagPath, g_WailsWhisper_Status
    if g_WailsWhisper_Recording
        return true
    if !WailsWhisper_IsReady() {
        reason := WailsWhisper_GetNotReadyReason()
        if (reason = "")
            reason := "Whisper 未就绪"
        WailsWhisper_ShowStatus(reason, "error")
        try TrayTip("语音输入", reason, "Icon!")
        return false
    }
    WailsWhisper_EnsureInputVisible()
    if !WailsWhisper_HasLocalModel() {
        WailsWhisper_ShowStatus("首次识别将下载模型，请稍候…", "loading")
    }
    g_WailsWhisper_WavPath := A_Temp . "\nmer_wails_voice_" . A_TickCount . ".wav"
    g_WailsWhisper_StopFlagPath := g_WailsWhisper_WavPath . ".stop"
    try FileDelete(g_WailsWhisper_WavPath)
    try FileDelete(g_WailsWhisper_StopFlagPath)
    try DirCreate((IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir) . "\Cache")
    spawn := WailsWhisper_SpawnRecordProcess(g_WailsWhisper_WavPath, g_WailsWhisper_StopFlagPath)
    if !spawn.ok {
        g_WailsWhisper_RecordPid := 0
        msg := spawn.err != "" ? spawn.err : "无法启动录音进程"
        WailsWhisper_ShowStatus(msg, "error")
        try TrayTip("语音输入", msg, "Icon!")
        return false
    }
    g_WailsWhisper_RecordPid := spawn.pid
    g_WailsWhisper_Recording := true
    g_WailsWhisper_Status := "recording"
    WailsWhisper_ShowStatus("正在聆听… 再按一次 CapsLock 结束并识别", "listening")
    return true
}

WailsWhisper_StopRecordingProcess() {
    global g_WailsWhisper_RecordPid, g_WailsWhisper_StopFlagPath
    pid := g_WailsWhisper_RecordPid
    g_WailsWhisper_RecordPid := 0
    if (g_WailsWhisper_StopFlagPath != "") {
        try FileAppend("", g_WailsWhisper_StopFlagPath, "UTF-8")
        catch {
            try FileDelete(g_WailsWhisper_StopFlagPath)
            try FileAppend("", g_WailsWhisper_StopFlagPath, "UTF-8")
        }
    }
    if !pid
        return
    if !ProcessWaitClose(pid, 12) {
        try ProcessClose(pid)
        catch {
        }
    }
    if (g_WailsWhisper_StopFlagPath != "") {
        try FileDelete(g_WailsWhisper_StopFlagPath)
    }
    Sleep(120)
}

WailsWhisper_StartTranscribeJob(wavPath) {
    global g_WailsWhisper_SttOut, g_WailsWhisper_SttWav, g_WailsWhisper_TranscribeDeadline, g_WailsWhisper_Status
    root := WailsWhisper_GetWhisperRoot()
    launcher := root . "\run_transcribe.cmd"
    if !FileExist(launcher) {
        g_WailsWhisper_Status := "idle"
        WailsWhisper_ShowStatus("缺少 run_transcribe.cmd", "error")
        return false
    }
    g_WailsWhisper_SttOut := A_Temp . "\nmer_wails_stt_" . A_TickCount . ".txt"
    g_WailsWhisper_SttWav := wavPath
    g_WailsWhisper_TranscribeDeadline := A_TickCount + 180000
    g_WailsWhisper_Status := "transcribing"
    try FileDelete(g_WailsWhisper_SttOut)
    if WailsWhisper_HasLocalModel() {
        modelDir := root . "\models\small"
        args := Format('--input "{1}" --model-dir "{2}" --language zh --output "{3}"', wavPath, modelDir, g_WailsWhisper_SttOut)
    } else {
        args := Format('--input "{1}" --model small --language zh --output "{2}"', wavPath, g_WailsWhisper_SttOut)
    }
    cmd := '"' . launcher . '" ' . args
    try {
        sh := ComObject("WScript.Shell")
        sh.CurrentDirectory := root
        sh.Run(cmd, 0, false)
    } catch as e {
        g_WailsWhisper_Status := "idle"
        WailsWhisper_ShowStatus("无法启动识别：" . e.Message, "error")
        return false
    }
    SetTimer(WailsWhisper_PollTranscribe, 500)
    return true
}

WailsWhisper_PollTranscribe(*) {
    global g_WailsWhisper_SttOut, g_WailsWhisper_SttWav, g_WailsWhisper_TranscribeDeadline, g_WailsWhisper_Status, g_WailsWhisper_WavPath
    outFile := g_WailsWhisper_SttOut
    wav := g_WailsWhisper_SttWav
    if (outFile != "" && FileExist(outFile)) {
        SetTimer(WailsWhisper_PollTranscribe, 0)
        text := ""
        try text := Trim(FileRead(outFile, "UTF-8"))
        try FileDelete(outFile)
        try FileDelete(wav)
        g_WailsWhisper_WavPath := ""
        g_WailsWhisper_SttOut := ""
        g_WailsWhisper_SttWav := ""
        if (text = "") {
            g_WailsWhisper_Status := "idle"
            WailsWhisper_ShowStatus("未识别到语音内容", "error")
            return
        }
        if FuncExists("WailsNative_SetInputText")
            WailsNative_SetInputText(text)
        WailsWhisper_FillInputText(text)
        g_WailsWhisper_Status := "idle"
        WailsWhisper_ShowStatus("识别完成", "ready")
        return
    }
    if (A_TickCount > g_WailsWhisper_TranscribeDeadline) {
        SetTimer(WailsWhisper_PollTranscribe, 0)
        try FileDelete(wav)
        g_WailsWhisper_WavPath := ""
        g_WailsWhisper_SttOut := ""
        g_WailsWhisper_SttWav := ""
        g_WailsWhisper_Status := "idle"
        WailsWhisper_ShowStatus("识别超时，请重试", "error")
    }
}

WailsWhisper_StopAndTranscribe(*) {
    global g_WailsWhisper_Recording, g_WailsWhisper_WavPath, g_WailsWhisper_Status
    if !g_WailsWhisper_Recording && g_WailsWhisper_Status != "recording"
        return
    g_WailsWhisper_Recording := false
    WailsWhisper_ShowStatus("正在结束录音…", "loading")
    WailsWhisper_EnsureInputVisible()
    WailsWhisper_StopRecordingProcess()
    wav := g_WailsWhisper_WavPath
    if !WailsWhisper_WaitForWav(wav) {
        g_WailsWhisper_Status := "idle"
        WailsWhisper_ShowStatus("未录到音频，请检查麦克风与 ffmpeg", "error")
        return
    }
    WailsWhisper_ShowStatus("正在识别语音…（约需数秒）", "loading")
    WailsWhisper_StartTranscribeJob(wav)
}

WailsWhisper_Cancel(*) {
    global g_WailsWhisper_Recording, g_WailsWhisper_WavPath, g_WailsWhisper_StopFlagPath, g_WailsWhisper_Status, g_WailsWhisper_RecordPid
    if g_WailsWhisper_Recording || g_WailsWhisper_RecordPid {
        WailsWhisper_StopRecordingProcess()
    }
    g_WailsWhisper_Recording := false
    g_WailsWhisper_Status := "idle"
    if (g_WailsWhisper_WavPath != "") {
        try FileDelete(g_WailsWhisper_WavPath)
        g_WailsWhisper_WavPath := ""
    }
    if (g_WailsWhisper_StopFlagPath != "") {
        try FileDelete(g_WailsWhisper_StopFlagPath)
        g_WailsWhisper_StopFlagPath := ""
    }
    WailsWhisper_ShowStatus("已取消语音输入", "idle")
}

WailsWhisper_IsRecording() {
    global g_WailsWhisper_Recording
    return g_WailsWhisper_Recording
}

; CapsLock 双击激活输入框后：若已在录音则结束识别；否则仅聚焦 Wails 输入框（点麦克风开始录音）
WailsWhisper_OnInputActivated() {
    if !WailsWhisperEnabled
        return
    if WailsWhisper_IsRecording() {
        SetTimer(WailsWhisper_StopAndTranscribe, -30)
        return
    }
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_DeferredFocus"))
        SetTimer(CommandPalette_DeferredFocus, -120)
    else if FuncExists("WailsInput_FocusWebInput")
        SetTimer(WailsInput_FocusWebInput, -120)
}

; CapsLock 单击（非双击）在录音中时结束并识别
WailsWhisper_TryStopOnCapsRelease() {
    if !WailsWhisper_IsRecording()
        return false
    SetTimer(WailsWhisper_StopAndTranscribe, -30)
    return true
}

if !(IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView)
    WailsWhisper_EnsureCmdWatcher()
