; VirtualKeyboard ↔ CursorHelper：WM_COPYDATA（独立运行的 VirtualKeyboard.ahk 发 vkExec 时仍可用）
; 需在 VirtualKeyboardExecCmd.ahk（VK_ExecCursorHelperCmd）之后 #Include

OnMessage(0x4A, _VkInteropCopyData)

_VkInteropRunExec(cmdId, *) {
    cid := Trim(String(cmdId))
    if (cid = "")
        return
    if FuncExists("VK_Execute")
        try VK_Execute(cid)
        catch as _e {
            if FuncExists("NmerCatch")
                try NmerCatch(A_ThisFunc, _e)
                catch {
                }
        }
}

_VkInteropCopyData(wParam, lParam, *) {
    sz := NumGet(lParam + 4, "UInt")
    ptr := NumGet(lParam + 8, "Ptr")
    if ((sz = 0 || !ptr) && A_PtrSize = 8) {
        sz := NumGet(lParam + 8, "UInt")
        ptr := NumGet(lParam + 16, "Ptr")
    }
    if (sz = 0 || !ptr)
        return false
    try {
        j := Jxon_Load(StrGet(ptr, sz, "UTF-8"))
    } catch {
        return false
    }
    if !(j is Map) || !j.Has("type")
        return false
    if (j["type"] = "bindingsReloaded") {
        VK_HandleBindingsReloaded()
        return true
    }
    if (j["type"] = "vkExec" && j.Has("cmdId")) {
        ; 立即 ACK，避免 SendMessageTimeout（主线程忙时同步 VK_Execute 会 exit=4）
        SetTimer(_VkInteropRunExec.Bind(String(j["cmdId"])), -1)
        return true
    }
    return false
}
