#Requires AutoHotkey v2.0

; CLI side effects (moved from VoiceInputModule)

VoiceInput_CliNativeTerminalEngine(Engine) {
  e := "|codex_cli|qwen_cli|gemini_cli|ollama_cli|claude_cli|deepseek_cli|kimi_cli|zhipu_cli|copilot_cli|"
  return InStr(e, "|" . Engine . "|")
}

VoiceInput_CliSimplePendingEngine(Engine) {
  e := "|codex_cli|qwen_cli|ollama_cli|claude_cli|deepseek_cli|kimi_cli|zhipu_cli|copilot_cli|"
  return InStr(e, "|" . Engine . "|")
}

VoiceInput_CliSendTextEngine(Engine) {
  e := "|codex_cli|ollama_cli|claude_cli|deepseek_cli|kimi_cli|zhipu_cli|copilot_cli|"
  return InStr(e, "|" . Engine . "|")
}

GetCLIAgentLaunchInfo(Engine) {
    switch Engine {
        case "codex_cli":
            return {Name: GetText("search_engine_cli_codex"), Command: GetPreferredCLIExecutable("codex_cli")}
        case "gemini_cli":
            return {Name: GetText("search_engine_cli_gemini"), Command: GetPreferredCLIExecutable("gemini_cli")}
        case "openclaw_cli":
            return {Name: GetText("search_engine_cli_openclaw"), Command: GetPreferredCLIExecutable("openclaw_cli")}
        case "qwen_cli":
            return {Name: GetText("search_engine_cli_qwen"), Command: GetPreferredCLIExecutable("qwen_cli")}
        case "ollama_cli":
            return {Name: GetText("search_engine_cli_ollama"), Command: GetPreferredCLIExecutable("ollama_cli")}
        case "claude_cli":
            return {Name: GetText("search_engine_cli_claude"), Command: GetPreferredCLIExecutable("claude_cli")}
        case "deepseek_cli":
            return {Name: GetText("search_engine_cli_deepseek"), Command: GetPreferredCLIExecutable("deepseek_cli")}
        case "kimi_cli":
            return {Name: GetText("search_engine_cli_kimi"), Command: GetPreferredCLIExecutable("kimi_cli")}
        case "zhipu_cli":
            return {Name: GetText("search_engine_cli_zhipu"), Command: GetPreferredCLIExecutable("zhipu_cli")}
        case "copilot_cli":
            return {Name: GetText("search_engine_cli_copilot"), Command: GetPreferredCLIExecutable("copilot_cli")}
        default:
            return 0
    }
}

; Claude 官方安装器默认路径：%USERPROFILE%\.local\bin\claude.exe
VoiceInput_GetUserProfileDir() {
    profile := EnvGet("USERPROFILE")
    if (profile != "") {
        return profile
    }
    drive := EnvGet("HOMEDRIVE")
    home := EnvGet("HOMEPATH")
    if (drive != "" && home != "") {
        return drive . home
    }
    return ""
}

VoiceInput_GetUserLocalBinExe(baseName) {
    profile := VoiceInput_GetUserProfileDir()
    if (profile = "") {
        return ""
    }
    fileName := baseName
    if (!RegExMatch(fileName, "i)\.(exe|cmd|bat)$")) {
        fileName .= ".exe"
    }
    full := profile . "\.local\bin\" . fileName
    return FileExist(full) ? full : ""
}

; CursorShortcut.ini [CLI] claude_cli=C:\...\claude.exe 可覆盖自动探测路径
ReadCLIExecutableOverride(Engine) {
    global ConfigFile
    if (!IsSet(ConfigFile) || ConfigFile = "") {
        return ""
    }
    try {
        path := Trim(IniRead(ConfigFile, "CLI", Engine, ""))
        if (path != "" && FileExist(path)) {
            return path
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return ""
}

VoiceInput_GetCliInstallHint(Engine) {
    switch Engine {
        case "claude_cli":
            return "`n`n默认安装位置：`n%USERPROFILE%\.local\bin\claude.exe`n`n请确认该文件存在；或在 CursorShortcut.ini 增加：`n[CLI]`nclaude_cli=%USERPROFILE%\.local\bin\claude.exe"
        case "codex_cli":
            return "`n`n安装：npm install -g @openai/codex（或官方 Codex CLI 包名），安装后执行 codex 验证。"
        case "gemini_cli":
            return "`n`n安装：npm install -g @google/gemini-cli，安装后执行 gemini 验证。"
        case "qwen_cli":
            return "`n`n安装：npm install -g @qwen-code/qwen-code，安装后执行 qwen 验证。"
        case "deepseek_cli":
            return "`n`n安装 DeepSeek 官方 CLI 并确保 dsvi 或 deepseek 在 PATH 中。"
        case "kimi_cli":
            return "`n`n安装 Kimi CLI（npm 全局 kimi）并确保 kimi 在 PATH 中。"
        case "zhipu_cli":
            return "`n`n安装：npm install -g @z_ai/coding-helper`n`n命令为 chelper（非 zhipu/glm）；安装后执行 chelper 验证。也可在 [CLI] zhipu_cli=完整路径\chelper.cmd 指定。"
        case "copilot_cli":
            return "`n`n安装 GitHub Copilot CLI，或将 copilot 可执行文件路径写入 [CLI] copilot_cli=..."
        case "ollama_cli":
            return "`n`n从 https://ollama.com 安装 Ollama，或确保 ollama.exe 在 PATH 中。"
        default:
            return "`n`n请安装对应 CLI 并加入 PATH，或在 CursorShortcut.ini 的 [CLI] 节配置可执行文件完整路径。"
    }
}

; 使用 where.exe 解析 PATH 中的可执行文件，返回首个存在的完整路径
TryResolveExecutableViaWhere(WhereExe, Name) {
    if (Name = "" || !FileExist(WhereExe)) {
        return ""
    }
    try {
        Shell := ComObject("WScript.Shell")
        Exec := Shell.Exec('"' . WhereExe . '" "' . Name . '"')
        while (Exec.Status = 0) {
            Sleep(20)
        }
        Out := Exec.StdOut.ReadAll()
        for Line in StrSplit(Out, "`n", "`r") {
            L := Trim(Line)
            if (L = "" || InStr(L, "INFO:") = 1) {
                continue
            }
            if (FileExist(L)) {
                return L
            }
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return ""
}

; 将裸名（如 codex.cmd）解析为 PATH 或 where.exe 找到的完整路径，避免 PowerShell 中 & 'codex.cmd' 因不在 PATH 而失败
ResolveBareCLIExecutableInPath(ExecutableName) {
    if (ExecutableName = "" || InStr(ExecutableName, "\")) {
        return ExecutableName
    }
    base := StrReplace(StrReplace(ExecutableName, ".cmd", ""), ".exe", "")
    if (base != "") {
        localBin := VoiceInput_GetUserLocalBinExe(base)
        if (localBin != "") {
            return localBin
        }
    }
    if (FileExist(A_ScriptDir . "\" . ExecutableName)) {
        return A_ScriptDir . "\" . ExecutableName
    }
    WhereExe := A_WinDir . "\System32\where.exe"
    R := TryResolveExecutableViaWhere(WhereExe, ExecutableName)
    if (R != "") {
        return R
    }
    Base := StrReplace(StrReplace(ExecutableName, ".cmd", ""), ".exe", "")
    if (Base != "" && Base != ExecutableName) {
        R := TryResolveExecutableViaWhere(WhereExe, Base)
        if (R != "") {
            return R
        }
    }
    return ExecutableName
}

GetPreferredCLIExecutable(Engine) {
    override := ReadCLIExecutableOverride(Engine)
    if (override != "") {
        return override
    }
    LocalAppDataDir := EnvGet("LOCALAPPDATA")
    Candidates := []
    switch Engine {
        case "codex_cli":
            Candidates := [
                A_AppData . "\npm-global\codex.cmd",
                A_AppData . "\npm\codex.cmd",
                LocalAppDataDir . "\npm\codex.cmd",
                LocalAppDataDir . "\npm-global\codex.cmd",
                "codex.cmd"
            ]
        case "gemini_cli":
            Candidates := [
                A_AppData . "\npm\gemini.cmd",
                A_AppData . "\npm-global\gemini.cmd",
                "gemini.cmd"
            ]
        case "openclaw_cli":
            Candidates := [
                LocalAppDataDir . "\pnpm\openclaw.cmd",
                A_AppData . "\npm\openclaw.cmd",
                A_AppData . "\npm-global\openclaw.cmd",
                "C:\Program Files\Qclaw\resources\cli\openclaw.cmd",
                "openclaw.cmd"
            ]
        case "qwen_cli":
            Candidates := [
                A_AppData . "\npm-global\qwen.cmd",
                A_AppData . "\npm\qwen.cmd",
                LocalAppDataDir . "\npm\qwen.cmd",
                LocalAppDataDir . "\npm-global\qwen.cmd",
                "qwen.cmd"
            ]
        case "ollama_cli":
            pf := EnvGet("ProgramFiles")
            Candidates := [
                pf . "\Ollama\ollama.exe",
                LocalAppDataDir . "\Programs\Ollama\ollama.exe",
                A_AppData . "\Programs\Ollama\ollama.exe",
                "ollama.exe",
                "ollama"
            ]
        case "claude_cli":
            localClaude := VoiceInput_GetUserLocalBinExe("claude")
            Candidates := []
            if (localClaude != "") {
                Candidates.Push(localClaude)
            } else {
                Candidates.Push(VoiceInput_GetUserProfileDir() . "\.local\bin\claude.exe")
            }
            Candidates.Push(
                A_AppData . "\npm-global\claude.cmd",
                A_AppData . "\npm\claude.cmd",
                LocalAppDataDir . "\npm\claude.cmd",
                LocalAppDataDir . "\npm-global\claude.cmd",
                LocalAppDataDir . "\pnpm\claude.cmd",
                A_AppData . "\pnpm\claude.cmd",
                "claude.cmd",
                "claude.exe",
                "claude"
            )
        case "deepseek_cli":
            Candidates := [
                A_AppData . "\npm-global\deepseek.cmd",
                A_AppData . "\npm\deepseek.cmd",
                LocalAppDataDir . "\npm\deepseek.cmd",
                "dsvi.cmd",
                "deepseek.cmd",
                "deepseek"
            ]
        case "kimi_cli":
            Candidates := [
                A_AppData . "\npm-global\kimi.cmd",
                A_AppData . "\npm\kimi.cmd",
                LocalAppDataDir . "\npm\kimi.cmd",
                LocalAppDataDir . "\npm-global\kimi.cmd",
                "kimi.cmd",
                "kimi"
            ]
        case "zhipu_cli":
            ; @z_ai/coding-helper 全局命令为 chelper（npm 下 chelper.cmd / chelper.ps1）
            Candidates := [
                A_AppData . "\npm\chelper.cmd",
                A_AppData . "\npm\chelper.ps1",
                A_AppData . "\npm-global\chelper.cmd",
                A_AppData . "\npm-global\chelper.ps1",
                LocalAppDataDir . "\npm\chelper.cmd",
                LocalAppDataDir . "\npm-global\chelper.cmd",
                A_AppData . "\npm-global\zhipu.cmd",
                A_AppData . "\npm\zhipu.cmd",
                LocalAppDataDir . "\npm\zhipu.cmd",
                A_AppData . "\npm\glm.cmd",
                "chelper.cmd",
                "chelper.ps1",
                "chelper",
                "zhipu.cmd",
                "glm.cmd",
                "zhipu",
                "glm"
            ]
        case "copilot_cli":
            Candidates := [
                LocalAppDataDir . "\Programs\GitHub Copilot\bin\copilot.cmd",
                LocalAppDataDir . "\Programs\GitHub Copilot\bin\copilot.exe",
                A_AppData . "\npm-global\copilot.cmd",
                A_AppData . "\npm\copilot.cmd",
                "copilot.cmd",
                "copilot"
            ]
        default:
            return ""
    }
    
    for _, Candidate in Candidates {
        if (InStr(Candidate, "\") && FileExist(Candidate)) {
            return Candidate
        }
    }
    Last := Candidates.Length > 0 ? Candidates[Candidates.Length] : ""
    Resolved := ResolveBareCLIExecutableInPath(Last)
    ; 仍未解析出磁盘路径时无法安全启动（避免 PowerShell 中 & 'codex.cmd' 报错）
    if (Resolved != "" && !InStr(Resolved, "\") && !InStr(Resolved, "/")) {
        return ""
    }
    return Resolved
}

GetCLIAgentWindowTitle(Engine) {
    ; 必须与 tools/voice-cli/cli_window_bridge.py 中 AGENTS 的英文 name 一致，否则无法匹配队列终端窗口标题
    switch Engine {
        case "codex_cli":
            return "CursorHelper AI - Codex"
        case "gemini_cli":
            return "CursorHelper AI - Gemini"
        case "openclaw_cli":
            return "CursorHelper AI - OpenClaw"
        case "qwen_cli":
            return "CursorHelper AI - Qwen"
        case "ollama_cli":
            return "CursorHelper AI - Ollama"
        case "claude_cli":
            return "CursorHelper AI - Claude"
        case "deepseek_cli":
            return "CursorHelper AI - DeepSeek"
        case "kimi_cli":
            return "CursorHelper AI - Kimi"
        case "zhipu_cli":
            return "CursorHelper AI - Zhipu"
        case "copilot_cli":
            return "CursorHelper AI - Copilot"
        default:
            AgentInfo := GetCLIAgentLaunchInfo(Engine)
            if (!AgentInfo || !IsObject(AgentInfo)) {
                return ""
            }
            return "CursorHelper AI - " . AgentInfo.Name
    }
}

FindCLIAgentWindow(Engine) {
    WindowTitle := GetCLIAgentWindowTitle(Engine)
    if (WindowTitle = "") {
        return 0
    }
    return WinExist(WindowTitle)
}

GetCLIAgentInputControl(WindowHwnd) {
    if (!WindowHwnd) {
        return ""
    }

    try {
        FocusedControl := ControlGetFocus("ahk_id " . WindowHwnd)
        if (FocusedControl != "") {
            return FocusedControl
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    PreferredPatterns := [
        "CASCADIA_HOSTING_WINDOW_CLASS",
        "Windows.UI",
        "TermControl",
        "Terminal",
        "Console",
        "Chrome_WidgetWin"
    ]

    try {
        Controls := WinGetControls("ahk_id " . WindowHwnd)
        for _, Pattern in PreferredPatterns {
            for _, ControlName in Controls {
                if (InStr(ControlName, Pattern)) {
                    return ControlName
                }
            }
        }
        if (Controls.Length > 0) {
            return Controls[1]
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return ""
}

RestoreClipboardDeferred(ClipboardBackup, DelayMs := 10000) {
    SetTimer((*) => (
        A_Clipboard := ClipboardBackup
    ), -DelayMs)
}

SendPromptToCLIAgentWindow(WindowHwnd, PromptText, Engine := "") {
    if (!WindowHwnd || PromptText = "") {
        return
    }

    try {
        LegacyGuard_RequestFocus("VoiceInput", WindowHwnd, 30, "voice_window_hwnd", 120)
        WinWaitActive("ahk_id " . WindowHwnd, , 3)
        Sleep((Engine = "qwen_cli" || Engine = "gemini_cli") ? 400 : 180)

        if VoiceInput_CliSendTextEngine(Engine) {
            SendText(PromptText)
            Sleep(100)
            Send("{Enter}")
            return
        }

        ; Qwen / Gemini TUI：Ctrl+V 往往无效；优先对终端子控件 ControlSend {Text}（与 Windows Terminal 兼容），否则回退 SendText
        if (Engine = "qwen_cli" || Engine = "gemini_cli") {
            TargetCtl := GetCLIAgentInputControl(WindowHwnd)
            if (TargetCtl != "") {
                try ControlFocus(TargetCtl, "ahk_id " . WindowHwnd)
                Sleep(150)
            }
            try {
                if (TargetCtl != "") {
                    ControlSend("{Text}" . PromptText, TargetCtl, "ahk_id " . WindowHwnd)
                    Sleep(80)
                    ControlSend("{Enter}", TargetCtl, "ahk_id " . WindowHwnd)
                } else {
                    SendText(PromptText)
                    Sleep(120)
                    Send("{Enter}")
                }
            } catch {
                SendText(PromptText)
                Sleep(120)
                Send("{Enter}")
            }
            return
        }

        TargetControl := GetCLIAgentInputControl(WindowHwnd)

        if (TargetControl != "") {
            ControlSend("{Text}" . PromptText, TargetControl, "ahk_id " . WindowHwnd)
            Sleep(120)
            ControlSend("{Enter}", TargetControl, "ahk_id " . WindowHwnd)
            return
        }

        ControlSend("{Text}" . PromptText, , "ahk_id " . WindowHwnd)
        Sleep(120)
        ControlSend("{Enter}", , "ahk_id " . WindowHwnd)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

GetWindowTextSafe(WindowHwnd) {
    if (!WindowHwnd) {
        return ""
    }
    try {
        return WinGetText("ahk_id " . WindowHwnd)
    } catch {
        return ""
    }
}

GeminiWindowNeedsAuth(WindowHwnd) {
    WindowText := StrLower(GetWindowTextSafe(WindowHwnd))
    ; 文本尚不可读时不当作「仍在登录页」，避免永远不发（终端刚启动时常短暂为空）
    if (WindowText = "") {
        return false
    }
    AuthPatterns := [
        "sign in",
        "login",
        "authenticate",
        "authentication",
        "browser",
        "google account",
        "continue in browser",
        "waiting for authentication",
        "open this url",
        "open the following link",
        "登录",
        "在浏览器",
        "verify it"
    ]
    for _, Pattern in AuthPatterns {
        if (InStr(WindowText, Pattern)) {
            return true
        }
    }
    return false
}

RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine := "gemini_cli") {
    global CLIAgentPendingPrompts, CLIAgentPromptMonitorRunning
    
    if (PromptText = "") {
        return
    }
    
    PendingKey := String(WindowHwnd)
    CLIAgentPendingPrompts[PendingKey] := {
        Hwnd: WindowHwnd,
        Prompt: PromptText,
        Engine: Engine,
        CreatedAt: A_TickCount,
        ProbeSent: false,
        InputWakeSent: false,
        LastWindowText: "",
        ReadySeenCount: 0,
        EmptyWindowTextRounds: 0,
        FallbackMode: false,
        GeminiLastText: "",
        GeminiStableRounds: 0,
        GeminiEmptyPolls: 0
    }
    
    if (!CLIAgentPromptMonitorRunning) {
        CLIAgentPromptMonitorRunning := true
        SetTimer(MonitorPendingCLIAgentPrompts, 500)
    }
}

QueuePromptForCLIAgent(Engine, WindowHwnd, PromptText) {
    AgentInfo := GetCLIAgentLaunchInfo(Engine)
    if (!AgentInfo || !WindowHwnd || PromptText = "") {
        return false
    }
    
    if (Engine = "gemini_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪（登录完成后界面稳定即发送）。", "提示", "Iconi 2")
        return true
    }
    
    if (Engine = "codex_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }
    
    if (Engine = "qwen_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }

    if (Engine = "ollama_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }

    if (Engine = "claude_cli" || Engine = "deepseek_cli" || Engine = "kimi_cli" || Engine = "zhipu_cli" || Engine = "copilot_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }
    
    return false
}

DispatchPromptToCLIAgent(Engine, LaunchResult, PromptText) {
    if (PromptText = "" || !IsObject(LaunchResult) || !LaunchResult.Hwnd) {
        return
    }
    
    if (Engine = "codex_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }
    
    if (Engine = "qwen_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }
    
    if (Engine = "gemini_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }

    if (Engine = "ollama_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }

    if (Engine = "claude_cli" || Engine = "deepseek_cli" || Engine = "kimi_cli" || Engine = "zhipu_cli" || Engine = "copilot_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    } else if (LaunchResult.IsNew) {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (AgentInfo && IsObject(AgentInfo)) {
            TrayTip(AgentInfo.Name . " 已打开。首次启动可能需要认证或等待加载，准备好后再次点击发送。", "提示", "Iconi 2")
        }
        return
    }
    
    SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
}

MonitorPendingCLIAgentPrompts() {
    global CLIAgentPendingPrompts, CLIAgentPromptMonitorRunning
    global CLIGeminiReadyMinMs, CLIGeminiStablePollsRequired, CLIGeminiForceSendAfterMs, CLIGeminiNoTextMinMs
    
    if (!IsSet(CLIAgentPendingPrompts) || CLIAgentPendingPrompts.Count = 0) {
        CLIAgentPromptMonitorRunning := false
        SetTimer(MonitorPendingCLIAgentPrompts, 0)
        return
    }
    
    CompletedKeys := []
    for Key, Pending in CLIAgentPendingPrompts {
        if (!WinExist("ahk_id " . Pending.Hwnd)) {
            CompletedKeys.Push(Key)
            continue
        }
        
        MaxWaitMs := (Pending.Engine = "gemini_cli") ? 120000 : 90000
        if ((A_TickCount - Pending.CreatedAt) > MaxWaitMs) {
            CompletedKeys.Push(Key)
            AgentInfo := GetCLIAgentLaunchInfo(Pending.Engine)
            AgentName := (AgentInfo && IsObject(AgentInfo)) ? AgentInfo.Name : Pending.Engine
            TrayTip(AgentName . " 等待就绪超时，请完成启动后重新发送。", "提示", "Icon! 2")
            continue
        }
        
        ; Gemini：登录态阻塞；有 WinGetText 时按文本稳定；无文本（Windows Terminal 常见）则按 EmptyPolls 回退，否则会永远不发送
        if (Pending.Engine = "gemini_cli") {
            LatestGeminiWindow := FindCLIAgentWindow("gemini_cli")
            if (LatestGeminiWindow) {
                Pending.Hwnd := LatestGeminiWindow
            }
            Hwnd := Pending.Hwnd
            if (!Hwnd || !WinExist("ahk_id " . Hwnd)) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            if (GeminiWindowNeedsAuth(Hwnd)) {
                Pending.GeminiStableRounds := 0
                Pending.GeminiLastText := ""
                Pending.GeminiEmptyPolls := 0
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            CurrentText := GetWindowTextSafe(Hwnd)
            Elapsed := A_TickCount - Pending.CreatedAt
            if (Elapsed < CLIGeminiReadyMinMs) {
                Pending.GeminiLastText := CurrentText
                Pending.GeminiStableRounds := 1
                Pending.GeminiEmptyPolls := 0
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            if (CurrentText = "") {
                if (Elapsed < CLIGeminiNoTextMinMs) {
                    Pending.GeminiStableRounds := 0
                    Pending.GeminiLastText := ""
                    Pending.GeminiEmptyPolls := 0
                    CLIAgentPendingPrompts[Key] := Pending
                    continue
                }
                Pending.GeminiLastText := ""
                Pending.GeminiStableRounds := 0
                Pending.GeminiEmptyPolls += 1
                CLIAgentPendingPrompts[Key] := Pending
                NoTextReady := (Pending.GeminiEmptyPolls >= CLIGeminiStablePollsRequired)
                ForceSend := (CLIGeminiForceSendAfterMs > 0 && Elapsed >= CLIGeminiForceSendAfterMs)
                if (NoTextReady || ForceSend) {
                    SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
                    CompletedKeys.Push(Key)
                }
                continue
            }
            Pending.GeminiEmptyPolls := 0
            if (CurrentText = Pending.GeminiLastText) {
                Pending.GeminiStableRounds += 1
            } else {
                Pending.GeminiLastText := CurrentText
                Pending.GeminiStableRounds := 1
            }
            CLIAgentPendingPrompts[Key] := Pending
            StableReady := (Pending.GeminiStableRounds >= CLIGeminiStablePollsRequired)
            ForceSend := false
            if (CLIGeminiForceSendAfterMs > 0 && Elapsed >= CLIGeminiForceSendAfterMs) {
                ForceSend := true
            }
            if (StableReady || ForceSend) {
                SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
                CompletedKeys.Push(Key)
            }
            continue
        }
        
        if VoiceInput_CliSimplePendingEngine(Pending.Engine) {
            RequiredDelay := (Pending.Engine = "qwen_cli") ? 4000 : ((Pending.Engine = "ollama_cli") ? 3500 : ((Pending.Engine = "claude_cli") ? 3000 : 2800))
            if ((A_TickCount - Pending.CreatedAt) < RequiredDelay) {
                continue
            }
            SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
            CompletedKeys.Push(Key)
            continue
        }
        
        CurrentWindowText := GetWindowTextSafe(Pending.Hwnd)
        if (CurrentWindowText = "") {
            Pending.EmptyWindowTextRounds += 1
            if (Pending.EmptyWindowTextRounds >= 20) {
                Pending.FallbackMode := true
            }
            CLIAgentPendingPrompts[Key] := Pending
        } else {
            Pending.EmptyWindowTextRounds := 0
            if (GeminiWindowNeedsAuth(Pending.Hwnd)) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
        }
        
        if (!Pending.FallbackMode && CurrentWindowText = "") {
            continue
        }
        
        if (!Pending.ProbeSent) {
            try {
                LegacyGuard_RequestFocus("VoiceInput", Pending.Hwnd, 30, "voice_pending_hwnd", 120)
                WinWaitActive("ahk_id " . Pending.Hwnd, , 3)
                Sleep(200)
                Send("{Enter}")
                Pending.ProbeSent := true
                Pending.CreatedAt := A_TickCount
                Pending.LastWindowText := CurrentWindowText
                Pending.ReadySeenCount := 0
                CLIAgentPendingPrompts[Key] := Pending
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            continue
        }
        
        if (Pending.FallbackMode) {
            if ((A_TickCount - Pending.CreatedAt) < 1800) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
            CompletedKeys.Push(Key)
            continue
        }
        
        if (CurrentWindowText != Pending.LastWindowText) {
            Pending.LastWindowText := CurrentWindowText
            Pending.ReadySeenCount := 1
            CLIAgentPendingPrompts[Key] := Pending
            continue
        }
        
        Pending.ReadySeenCount += 1
        CLIAgentPendingPrompts[Key] := Pending
        if (Pending.ReadySeenCount < 3) {
            continue
        }
        
        Sleep(200)
        SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
        CompletedKeys.Push(Key)
    }
    
    for _, Key in CompletedKeys {
        try CLIAgentPendingPrompts.Delete(Key)
    }
    
    if (CLIAgentPendingPrompts.Count = 0) {
        CLIAgentPromptMonitorRunning := false
        SetTimer(MonitorPendingCLIAgentPrompts, 0)
    }
}

OpenCLIAgentTerminal(Engine) {
    AgentInfo := GetCLIAgentLaunchInfo(Engine)
    if (!AgentInfo || !IsObject(AgentInfo)) {
        throw Error("未配置该 CLI: " . Engine)
    }
    if (AgentInfo.Command = "") {
        throw Error("找不到 " . AgentInfo.Name . " 可执行文件。请安装 CLI 或将其加入系统 PATH。" . VoiceInput_GetCliInstallHint(Engine))
    }
    
    ExistingWindow := FindCLIAgentWindow(Engine)
    if (ExistingWindow) {
        try {
            LegacyGuard_RequestFocus("VoiceInput", ExistingWindow, 30, "voice_existing_hwnd", 120)
            WinWaitActive("ahk_id " . ExistingWindow, , 3)
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return {Hwnd: ExistingWindow, IsNew: false}
    }
    
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    
    WinTitleStr := GetCLIAgentWindowTitle(Engine)
    if (WinTitleStr = "") {
        WinTitleStr := "CursorHelper AI - " . AgentInfo.Name
    }
    ; Gemini：与 Qwen 一样走原生交互终端；启动前由 gemini_native_terminal.ps1 加载 .env / 注册表等（与队列 worker 共用 gemini_env.ps1）
    if (Engine = "gemini_cli") {
        NativeScript := Nmer_VoiceCliScript("gemini_native_terminal.ps1")
        if (!FileExist(NativeScript)) {
            throw Error("找不到 Gemini 启动脚本: " . NativeScript)
        }
        EscapedTitle := StrReplace(WinTitleStr, "'", "''")
        EscapedWorkDir := StrReplace(A_ScriptDir, "'", "''")
        EscapedExe := StrReplace(AgentInfo.Command, "'", "''")
        CommandLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -File "' . NativeScript . '" -Title "' . EscapedTitle . '" -Workdir "' . EscapedWorkDir . '" -Executable "' . EscapedExe . '"'
        Run(CommandLine, A_ScriptDir, , &TerminalPid)
        WinWaitActive("ahk_pid " . TerminalPid, , 5)
        return {Hwnd: WinExist("ahk_pid " . TerminalPid), IsNew: true}
    }
    EscapedTitle := StrReplace(WinTitleStr, "'", "''")
    EscapedWorkDir := StrReplace(A_ScriptDir, "'", "''")
    EscapedCommand := StrReplace(AgentInfo.Command, "'", "''")
    PowerShellCommand := "$Host.UI.RawUI.WindowTitle = '" . EscapedTitle . "'; Set-Location -LiteralPath '" . EscapedWorkDir . "'; & '" . EscapedCommand . "'"
    CommandLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -Command "' . PowerShellCommand . '"'
    Run(CommandLine, A_ScriptDir, , &TerminalPid)
    WinWaitActive("ahk_pid " . TerminalPid, , 5)
    return {Hwnd: WinExist("ahk_pid " . TerminalPid), IsNew: true}
}

; 通过 PowerShell 启动 cli_queue_worker.ps1（与 Python 版 bridge 等价），不依赖系统已安装 python
InvokePythonCLIBridge(Engines, PromptText := "", Action := "send") {
    global A_ScriptDir
    if (!IsObject(Engines) || Engines.Length = 0) {
        return 0
    }
    if (Action = "send" && PromptText = "") {
        return 0
    }
    WorkerScript := Nmer_VoiceCliScript("cli_queue_worker.ps1")
    if (!FileExist(WorkerScript)) {
        TrayTip("找不到 CLI 队列脚本: " . WorkerScript, "错误", "Iconx 2")
        return 0
    }
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        TrayTip("找不到 Windows PowerShell", "错误", "Iconx 2")
        return 0
    }
    OkCount := 0
    for _, Engine in Engines {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (!AgentInfo || !IsObject(AgentInfo) || AgentInfo.Command = "") {
            hint := VoiceInput_GetCliInstallHint(Engine)
            TrayTip("未找到 " . Engine . " 的可执行文件。" . hint, "CLI", "Iconx 5")
            continue
        }
        Title := GetCLIAgentWindowTitle(Engine)
        if (Title = "") {
            continue
        }
        QueueDir := A_ScriptDir . "\cache\cli_queue\" . Engine
        try DirCreate(QueueDir)
        Hwnd := FindCLIAgentWindow(Engine)
        if (!Hwnd) {
            CmdLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -File "' . WorkerScript . '"'
            CmdLine .= ' -Engine "' . Engine . '" -Title "' . Title . '" -Workdir "' . A_ScriptDir . '" -QueueDir "' . QueueDir . '" -Executable "' . AgentInfo.Command . '"'
            try {
                Run(CmdLine, A_ScriptDir)
            } catch as err {
                TrayTip("启动 " . AgentInfo.Name . " 失败: " . err.Message, "错误", "Iconx 2")
                continue
            }
            Deadline := A_TickCount + 12000
            while (A_TickCount < Deadline) {
                Hwnd := FindCLIAgentWindow(Engine)
                if (Hwnd) {
                    break
                }
                Sleep(250)
            }
        }
        if (!Hwnd) {
            TrayTip("超时：未检测到 " . AgentInfo.Name . " 终端窗口", "错误", "Iconx 2")
            continue
        }
        if (Action = "send") {
            PromptFile := QueueDir . "\" . A_TickCount . "_" . Random(1, 999999) . ".txt"
            try FileAppend(PromptText, PromptFile, "UTF-8")
        }
        try {
            LegacyGuard_RequestFocus("VoiceInput", Hwnd, 30, "voice_hwnd", 120)
            WinWaitActive("ahk_id " . Hwnd, , 2)
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        OkCount += 1
        Sleep(150)
    }
    return OkCount
}

; 直接 PowerShell 里 & qwen.cmd / codex.cmd / gemini（无参即交互式），用户可在终端内连续输入；队列 worker 仅用于 openclaw 等非原生 CLI
ShouldUseNativeCLITerminal(Engine) {
    return VoiceInput_CliNativeTerminalEngine(Engine)
}

VoiceInputEffect_DispatchCliAgents(PromptText := "", Action := "send", Engines := 0) {
    global SearchCenterSelectedEngines
    engineList := (IsObject(Engines) && Engines.Length > 0) ? Engines : SearchCenterSelectedEngines
    if (!IsObject(engineList) || engineList.Length = 0) {
        TrayTip("请至少选择一个 CLI", "提示", "Icon! 2")
        return
    }
    SearchCenterSelectedEngines := engineList
    bridgeAction := (Action != "") ? Action : ((PromptText = "") ? "open" : "send")
    
    NativeEngines := []
    BridgeEngines := []
    for _, Engine in SearchCenterSelectedEngines {
        if (ShouldUseNativeCLITerminal(Engine)) {
            NativeEngines.Push(Engine)
        } else {
            BridgeEngines.Push(Engine)
        }
    }
    
    ProcessedCount := 0
    for Index, Engine in NativeEngines {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (!AgentInfo || !IsObject(AgentInfo)) {
            continue
        }
        try {
            LaunchResult := OpenCLIAgentTerminal(Engine)
            ProcessedCount += 1
            if (PromptText != "") {
                DispatchPromptToCLIAgent(Engine, LaunchResult, PromptText)
            }
            if (Index < NativeEngines.Length) {
                Sleep(400)
            }
        } catch as err {
            if (InStr(err.Message, "找不到") && InStr(err.Message, "可执行文件")) {
                MsgBox("启动 " . AgentInfo.Name . " 失败`n`n" . err.Message, "CLI", "Icon!")
            } else {
                TrayTip("启动 " . AgentInfo.Name . " 失败: " . err.Message, "错误", "Iconx 2")
            }
        }
    }
    
    if (BridgeEngines.Length > 0) {
        BridgeOk := InvokePythonCLIBridge(BridgeEngines, PromptText, bridgeAction)
        if (BridgeOk > 0) {
            ProcessedCount += BridgeOk
        }
    }
    
    if (ProcessedCount > 0) {
        if (PromptText = "") {
            TrayTip("正在打开 " . ProcessedCount . " 个 AI 终端", "提示", "Iconi 1")
        } else {
            TrayTip("正在发送到 " . ProcessedCount . " 个 AI 终端", "提示", "Iconi 1")
        }
    }
}
