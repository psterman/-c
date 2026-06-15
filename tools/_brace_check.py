# -*- coding: utf-8 -*-
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / "modules" / "LocalPaths.ahk"
text = path.read_text(encoding="utf-8")

depth = 0
in_str = None
escape = False
first_neg = None
for lineno, line in enumerate(text.splitlines(), 1):
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == in_str:
                in_str = None
            i += 1
            continue
        if c in ('"', "'"):
            in_str = c
            i += 1
            continue
        if c == ";":
            break
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth < 0 and first_neg is None:
                first_neg = (lineno, line, depth)
        i += 1

print("final depth:", depth)
if first_neg:
    print("first negative:", first_neg[0], repr(first_neg[1]))

# bisect: test prefix of file
ahk = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
for n in [100, 200, 300, 365, 380, 383, 400, 500, 793]:
    lines = text.splitlines()[:n]
    # close open braces naively
    d = 0
    in_str = None
    escape = False
    for line in lines:
        i = 0
        while i < len(line):
            c = line[i]
            if in_str:
                if escape:
                    escape = False
                elif c == "\\":
                    escape = True
                elif c == in_str:
                    in_str = None
                i += 1
                continue
            if c in ('"', "'"):
                in_str = c
                i += 1
                continue
            if c == ";":
                break
            if c == "{":
                d += 1
            elif c == "}":
                d -= 1
            i += 1
    suffix = "\n" + ("}\n" * max(d, 0))
    tmp = root / f"_lp_prefix_{n}.ahk"
    tmp.write_text("\n".join(lines) + suffix, encoding="utf-8")
    r = subprocess.run([ahk, "/ErrorStdOut", str(tmp)], capture_output=True, text=True)
    ok = r.returncode == 0
    err = (r.stderr or r.stdout or "").strip().split("\n")[0] if not ok else "OK"
    print(f"prefix {n}: {'OK' if ok else err}")
