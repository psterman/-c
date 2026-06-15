# -*- coding: utf-8 -*-
import re
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "modules" / "LegacyClipboardListView.ahk"
text = p.read_text(encoding="utf-8")

block = re.compile(
    r"(\s+)if \(SearchKeyword != \"\"\) \{"
    r"(?:.*?"
    r"escapedKeyword := StrReplace\(SearchKeyword.*?"
    r"\s+\}\s*\n)",
    re.DOTALL,
)

def repl(m):
    indent = m.group(1)
    inner = (
        f'{indent}if (SearchKeyword != "") {{\n'
        f'{indent}    SQL := "SELECT name FROM sqlite_master WHERE type=\'table\' AND name=\'ClipboardHistory\'"\n'
        f'{indent}    table := ""\n'
        f'{indent}    hasFTS5Table := false\n'
        f'{indent}    if (ClipboardFTS5DB.GetTable(SQL, &table)) {{\n'
        f'{indent}        if (table.HasRows && table.Rows.Length > 0) {{\n'
        f'{indent}            hasFTS5Table := true\n'
        f'{indent}        }}\n'
        f'{indent}    }}\n'
        f'{indent}    _LCLV_AppendKeywordSearch(whereConditions, &queryParams, SearchKeyword, hasFTS5Table)\n'
        f'{indent}}}\n'
    )
    return inner

new, n = block.subn(repl, text)
print("blocks replaced:", n)

lines = new.splitlines()
out = []
for i, line in enumerate(lines):
    out.append(line)
    if re.match(r"\s+whereConditions := \[\]\s*$", line):
        indent = re.match(r"^(\s+)", line).group(1)
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if "queryParams" not in nxt:
            out.append(f"{indent}queryParams := []")

new = "\n".join(out) + "\n"
new = new.replace(
    "querySuccess := ClipboardFTS5DB.GetTable(SQL, &ResultTable)",
    "querySuccess := _LCLV_RunClipQuery(SQL, &ResultTable, queryParams*)",
)
new = new.replace(
    "if (ClipboardFTS5DB.GetTable(SQL, &ResultTable)",
    "if (_LCLV_RunClipQuery(SQL, &ResultTable, queryParams*)",
)
p.write_text(new, encoding="utf-8")
