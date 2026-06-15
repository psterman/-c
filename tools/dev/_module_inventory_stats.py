#!/usr/bin/env python3
import os, glob, re, json
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOD = os.path.join(ROOT, "modules")
MAIN = os.path.join(ROOT, "牛马.ahk")

main = open(MAIN, encoding="utf-8", errors="ignore").read()
includes = re.findall(r"#Include\s+[\"']?([^\"'\r\n]+)", main, re.I)
inc_norm = {os.path.basename(p.replace("/", "\\")).lower() for p in includes if p.lower().endswith(".ahk")}

rows = []
for p in glob.glob(os.path.join(MOD, "*.ahk")):
    sz = os.path.getsize(p)
    with open(p, encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    hint = ""
    for line in lines[:5]:
        line = line.strip()
        if line.startswith(";") and len(line) > 2:
            hint = line.lstrip(";").strip()[:100]
            break
    base = os.path.basename(p)
    rows.append({
        "file": base,
        "kb": round(sz / 1024, 1),
        "lines": len(lines),
        "main_include": base.lower() in inc_norm,
        "hint": hint,
    })
rows.sort(key=lambda r: (-r["kb"], -r["lines"]))

# FloatingToolbar prefix groups
ftb_path = os.path.join(MOD, "FloatingToolbar.ahk")
ftb = open(ftb_path, encoding="utf-8", errors="ignore").read()
funcs = re.findall(r"^([A-Za-z_][\w]*)\s*\(", ftb, re.M)
ftb_funcs = [f for f in funcs if f.startswith("FloatingToolbar_")]
groups = defaultdict(list)
for fn in ftb_funcs:
    rest = fn[len("FloatingToolbar_"):]
    if any(k in rest for k in ("Chat", "Ttyd", "Node", "Audit", "Bridge")):
        g = "chat_ttyd_bridge"
    elif any(k in rest for k in ("SearchCenter", "Search")):
        g = "search_center"
    elif any(k in rest for k in ("Screenshot", "Shot", "Capture")):
        g = "screenshot"
    elif any(k in rest for k in ("Dpi", "Scale", "WorkArea", "Clamp", "Drawer", "Layout")):
        g = "layout_dpi"
    elif any(k in rest for k in ("WebView", "Web", "Post", "Message", "Notify")):
        g = "webview_lifecycle"
    elif any(k in rest for k in ("Show", "Hide", "Toggle", "Open", "Close", "Boot")):
        g = "show_hide"
    else:
        g = "misc"
    groups[g].append(fn)

out = {
    "module_count": len(rows),
    "main_module_includes": sum(1 for i in includes if "modules" in i.lower()),
    "main_lines": main.count("\n") + 1,
    "main_kb": round(os.path.getsize(MAIN) / 1024, 1),
    "top15": rows[:15],
    "ftb_func_count": len(ftb_funcs),
    "ftb_groups": {k: {"count": len(v), "sample": v[:8]} for k, v in sorted(groups.items(), key=lambda x: -len(x[1]))},
}
out_path = os.path.join(ROOT, "Cache", "ci", "module_inventory_stats.json")
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print(out_path)
