#Requires AutoHotkey v2.0
p1 := Run('cmd.exe /c echo ok', , "Hide")
p2 := 0
Run('cmd.exe /c echo ok2', , "Hide", &p2)
FileAppend("p1=[" p1 "] p2=[" p2 "]`n", A_Temp . "\nmer_ahk_runtest5.txt")
