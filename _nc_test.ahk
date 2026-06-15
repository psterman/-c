#Requires AutoHotkey v2.0
NmerCatch(a,b){
    try {
        try msg := err.Message
        catch
            msg := String(err)
    }
}
ExitApp
