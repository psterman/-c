#Requires AutoHotkey v2.0
#Include ..\..\lib\ahk\Jxon.ahk
#Include ..\..\modules\LlmApiPing.ahk
#Include ..\..\modules\UserStudio.ahk

logPath := A_ScriptDir . "\..\..\Cache\debug\openclaw_gateway_probe.log"
DirCreate(A_ScriptDir . "\..\..\Cache\debug")
lines := [FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " probe"]

t0 := A_TickCount
tcpOk := LlmApiPing_TcpPortOpen("127.0.0.1", 18789, 2500)
lines.Push("tcp=" . (tcpOk ? "1" : "0") . " ms=" . (A_TickCount - t0))

t1 := A_TickCount
cliOk := LlmApiPing_OpenClawGatewayStatusOk(15000)
lines.Push("cli=" . (cliOk ? "1" : "0") . " ms=" . (A_TickCount - t1))

info := UserStudio_ProbeOpenClawGatewayToken()
tok := Trim(String(info.Get("token", "")))
lines.Push("tokenLen=" . StrLen(tok))

t2 := A_TickCount
r := LlmApiPing_TestOpenClaw("http://127.0.0.1:18789", tok, 15000)
lines.Push("TestOpenClaw ok=" . (r.Get("ok", false) ? "1" : "0") . " ms=" . (A_TickCount - t2) . " err=" . r.Get("error", ""))

FileAppend(lines.Join("`n") . "`n", logPath, "UTF-8")
ExitApp 0
