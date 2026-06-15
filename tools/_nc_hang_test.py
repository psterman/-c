# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ahk = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

cases = {
    "empty": "NmerCatch(a,b){}",
    "try_only": "NmerCatch(a,b){ try { x:=1 } }",
    "try_catch": "NmerCatch(a,b){ try { x:=1 } catch { } }",
    "try_catch_var": "NmerCatch(a,b){ try { x:=1 } catch e { } }",
    "oneline_try_catch": """NmerCatch(a,b){
    try msg := err.Message
    catch
        msg := ""
}""",
    "nested": """NmerCatch(a,b){
    try {
        try msg := err.Message
        catch
            msg := String(err)
    }
}""",
}

for label, body in cases.items():
    p = root / "_nc_test.ahk"
    p.write_text("#Requires AutoHotkey v2.0\n" + body + "\nExitApp\n", encoding="utf-8")
    try:
        r = subprocess.run([ahk, "/ErrorStdOut", str(p)], capture_output=True, text=True, timeout=3)
        print(label, r.returncode, (r.stderr or "")[:80])
    except subprocess.TimeoutExpired:
        print(label, "TIMEOUT")
