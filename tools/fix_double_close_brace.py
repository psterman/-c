# -*- coding: utf-8 -*-
"""Fix duplicated closing braces from fix_inline_catch.py bug."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pat = re.compile(r"^(\s+)\}\}\s*$", re.MULTILINE)
skip_dirs = {".git", "node_modules", "Cache", "local"}
total = 0

for path in sorted(root.rglob("*.ahk")):
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.name.startswith("_"):
        continue
    raw = path.read_text(encoding="utf-8")
    fixed, n = pat.subn(r"\1}", raw)
    if n:
        path.write_text(fixed, encoding="utf-8")
        print(f"{path.relative_to(root)}: {n}")
        total += n

print(f"done, {total} lines")
