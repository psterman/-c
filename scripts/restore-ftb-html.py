# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "FloatingToolbarStrip.html"
GOOD_REV = "ac39bf6"

blob = subprocess.check_output(
    ["git", "-C", str(ROOT), "show", f"{GOOD_REV}:FloatingToolbarStrip.html"]
)
text = blob.decode("utf-8")
assert "\u9996\u6b21\u4f7f\u7528" in text, "expected 首次使用 in restored blob"
TARGET.write_text(text, encoding="utf-8", newline="\n")
print("restored", TARGET, "from", GOOD_REV)
