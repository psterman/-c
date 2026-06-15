# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / "modules" / "LocalPaths.ahk").read_text(encoding="utf-8")
lines = text.splitlines()
ahk = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"


def run_include(content: str) -> str:
    p = root / "_lp_part.ahk"
    wrap = root / "_lp_part_wrap.ahk"
    p.write_text(content, encoding="utf-8")
    wrap.write_text("#Requires AutoHotkey v2.0\n#Include _lp_part.ahk\nExitApp\n", encoding="utf-8")
    try:
        r = subprocess.run([ahk, "/ErrorStdOut", str(wrap)], capture_output=True, text=True, timeout=3)
        if r.returncode != 0:
            return "ERR:" + (r.stderr or r.stdout).strip().split("\n")[0]
        return "OK"
    except subprocess.TimeoutExpired:
        return "TIMEOUT"


for n in [50, 100, 200, 300, 365, 400, 500, 600, 700, len(lines)]:
    chunk = "\n".join(lines[:n])
    result = run_include(chunk)
    print(f"lines {n}: {result}")
