#Requires AutoHotkey v2.0

NmerCatch(scope, err, detail := "") {
    msg := ""
    try {
        msg := err.Message
    } catch {
        msg := String(err)
    }

    file := ""
    line := 0
    what := ""
    stack := ""
    try file := err.File
    catch {
    }
    try line := err.Line
    catch {
    }
    try what := err.What
    catch {
    }
    try stack := err.Stack
    catch {
        stack := ""
    }

    extra := ""
    if (file != "")
        extra .= " file=" . file
    if (line != 0)
        extra .= " line=" . line
    if (what != "")
        extra .= " what=" . what
    if (stack != "")
        extra .= " stack=" . stack

    entry := msg . extra
    if (detail != "")
        entry := detail . " | " . entry

    try NMER_Log(scope, "catch", entry)
    catch {
    }
}

ExitApp
