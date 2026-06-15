# -*- coding: utf-8 -*-
"""Expand single-line `catch as _e { ... }` blocks (AHK v2 parse bug)."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pattern = re.compile(
    r"^([ \t]*)(.*?catch as _e \{) (.*?)(\}[ \t]*)$",
    re.MULTILINE,
)

skip_dirs = {".git", "node_modules", "Cache", "local"}


def fix_text(text: str) -> tuple[str, int]:
    count = 0

    def repl(m: re.Match) -> str:
        nonlocal count
        indent, head, body, tail = m.group(1), m.group(2), m.group(3), m.group(4)
        if "\n" in body or body.strip() == "":
            return m.group(0)
        count += 1
        inner = indent + "    "
        return f"{indent}{head}\n{inner}{body}\n{indent}}}"

    return pattern.sub(repl, text), count


total = 0
for path in sorted(root.rglob("*.ahk")):
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.name.startswith("_"):
        continue
    raw = path.read_text(encoding="utf-8")
    fixed, n = fix_text(raw)
    if n:
        path.write_text(fixed, encoding="utf-8")
        print(f"{path.relative_to(root)}: {n}")
        total += n

print(f"done, {total} replacements")
