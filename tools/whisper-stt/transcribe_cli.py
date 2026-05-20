#!/usr/bin/env python3
"""Local speech-to-text CLI for nmer hole overlay (faster-whisper)."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Transcribe audio with faster-whisper")
    parser.add_argument("--input", required=True, help="Audio file path")
    parser.add_argument(
        "--model-dir",
        default="",
        help="Local model directory (e.g. models/small). If empty, uses --model name.",
    )
    parser.add_argument("--model", default="small", help="Model name when --model-dir is empty")
    parser.add_argument("--language", default="zh", help="Language code; empty = auto")
    parser.add_argument("--output", default="", help="Optional UTF-8 output file")
    args = parser.parse_args()

    audio = Path(args.input)
    if not audio.is_file():
        print(f"error: file not found: {audio}", file=sys.stderr)
        return 2

    model_ref = args.model_dir.strip() or args.model.strip() or "small"
    lang = args.language.strip() or None

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("error: faster-whisper not installed", file=sys.stderr)
        return 3

    model = WhisperModel(model_ref, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(str(audio), language=lang)
    text = "".join(seg.text for seg in segments).strip()

    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")

    # stdout for AHK RunWait capture
    if text:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
