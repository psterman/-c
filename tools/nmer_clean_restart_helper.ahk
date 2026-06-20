; 等待父进程退出后拉起主脚本（托盘/热键干净重启专用，勿直接运行）
#Requires AutoHotkey v2.0
#SingleInstance Off

parentPid := Integer(A_Args[1])
ahkExe := A_Args[2]
launchTarget := A_Args[3]
mainScript := (A_Args.Length >= 4) ? A_Args[4] : launchTarget

if (parentPid < 1 || ahkExe = "" || launchTarget = "" || !FileExist(ahkExe) || !FileExist(launchTarget)) {
    ExitApp(2)
}

while ProcessExist(parentPid)
    Sleep(200)

try {
    if (mainScript != launchTarget && FileExist(launchTarget))
        Run('"' . ahkExe . '" "' . launchTarget . '" "' . mainScript . '"', , "Hide")
    else
        Run('"' . ahkExe . '" "' . launchTarget . '"', , "Hide")
} catch {
    ExitApp(1)
}
ExitApp(0)
