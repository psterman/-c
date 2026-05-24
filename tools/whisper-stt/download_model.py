#!/usr/bin/env python3
"""Download Systran/faster-whisper-small into models/small (model.bin)."""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parent
    target = root / "models" / "small"
    target.mkdir(parents=True, exist_ok=True)
    if (target / "model.bin").is_file():
        print("already exists:", target / "model.bin")
        return 0
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("error: pip install huggingface_hub", file=sys.stderr)
        return 2
    print("downloading Systran/faster-whisper-small ->", target)
    snapshot_download("Systran/faster-whisper-small", local_dir=str(target))
    if not (target / "model.bin").is_file():
        print("error: model.bin still missing after download", file=sys.stderr)
        return 3
    print("ok:", target / "model.bin")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
