# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
commits = subprocess.check_output(
    ["git", "-C", str(ROOT), "log", "--oneline", "-15", "--", "FloatingToolbarStrip.html"],
    text=True,
    encoding="utf-8",
    errors="replace",
).strip().splitlines()

out = []
for line in commits:
    rev = line.split()[0]
    try:
        blob = subprocess.check_output(
            ["git", "-C", str(ROOT), "show", f"{rev}:FloatingToolbarStrip.html"]
        )
        text = blob.decode("utf-8")
    except Exception as e:
        out.append(f"{rev} decode error {e}")
        continue
    ok = "\u9996\u6b21" in text  # 首次
    garbled = "\u68df\u6808" in text  # 棣栨
    i = text.find('id="empty"')
    sample = text[i + 12 : i + 55] if i >= 0 else ""
    out.append(f"{rev} ok={ok} garbled={garbled} sample={sample!r}")

Path(ROOT / "scripts" / "ftb-commit-scan.txt").write_text("\n".join(out), encoding="utf-8")
