#Requires AutoHotkey v2.0
out := A_ScriptDir . "\..\Cache\ini_test.txt"
try FileDelete(out)
p := A_ScriptDir . "\SQLiteDB.ini"
FileAppend("iniPath=" . p . "`n", out, "UTF-8")
FileAppend("exists=" . FileExist(p) . "`n", out, "UTF-8")
FileAppend("raw=" . FileRead(p) . "`n", out, "UTF-8")
v := IniRead(p, "Main", "DllPath", "DEFAULT_MISSING")
FileAppend("DllPath=" . v . "`n", out, "UTF-8")
ExitApp 0
