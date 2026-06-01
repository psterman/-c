import re
from pathlib import Path

p = Path(__file__).resolve().parent.parent / "FloatingToolbarStrip.html"
h = p.read_text(encoding="utf-8")
pattern = r'(<div id="collapsedBtns" class="icon-btns">).*?(</div>\s*</div>\s*<motion id="drawerRoot">)'
pattern = pattern.replace("motion", "div")
h2, n = re.subn(pattern, r"\1\2", h, count=1, flags=re.S)
if n != 1:
    raise SystemExit(f"replace count {n}")
p.write_text(h2, encoding="utf-8")
print("cleared static collapsedBtns")
