#Requires AutoHotkey v2.0
#Include ..\lib\Jxon.ahk
items := []
items.Push(Map("cmdId", "sc_activate_search", "name", "搜索", "iconClass", "fa-solid fa-magnifying-glass"))
items.Push(Map("cmdId", "qa_clipboard", "name", "剪贴板", "iconClass", "fa-solid fa-clipboard"))
payload := Map("type", "set_toolbar_cmds", "items", items)
FileAppend(Jxon_Dump(payload) "`n", "scripts\test-ftb-json.out", "UTF-8")
