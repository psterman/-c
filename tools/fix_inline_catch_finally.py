# -*- coding: utf-8 -*-
"""Expand remaining single-line catch blocks (incl. try/catch/finally)."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skip_dirs = {".git", "node_modules", "Cache", "local"}

patterns = [
    re.compile(
        r"^([ \t]*)(.*?catch as _e \{) (NmerCatch\(A_ThisFunc, _e\)) (\})(\s*finally\b.*)$",
        re.MULTILINE,
    ),
    re.compile(
        r"^([ \t]*)(catch as _e \{) (NmerCatch\(A_ThisFunc, _e\)) (\})(\s*finally\b.*)$",
        re.MULTILINE,
    ),
    re.compile(
        r"^([ \t]*)(.*?catch as _e \{) ([^}\n]+) (\})(\s*)$",
        re.MULTILINE,
    ),
]


def expand_catch_line(m: re.Match) -> str:
    indent, head, body, close, tail = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    if "\n" in body:
        return m.group(0)
    inner = indent + "    "
    return f"{indent}{head}\n{inner}{body}\n{indent}{close}{tail}"


total = 0
for path in sorted(root.rglob("*.ahk")):
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.name.startswith("_"):
        continue
    fixed = path.read_text(encoding="utf-8")
    n_file = 0
    for pat in patterns:
        fixed, n = pat.subn(expand_catch_line, fixed)
        n_file += n
    if n_file:
        path.write_text(fixed, encoding="utf-8")
        print(f"{path.relative_to(root)}: {n_file}")
        total += n_file

print(f"done, {total}")
