#!/usr/bin/env python3
"""Record microphone to 16kHz mono WAV via ffmpeg dshow (Windows)."""
from __future__ import annotations

import argparse
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import wave
from pathlib import Path


def find_ffmpeg() -> str:
    for name in ("ffmpeg", "ffmpeg.exe"):
        found = shutil.which(name)
        if found:
            return found
    script_root = Path(__file__).resolve().parents[2]
    bundled = script_root / "lib" / "ffmpeg.exe"
    if bundled.is_file():
        return str(bundled)
    return "ffmpeg"


def first_dshow_audio_device(ffmpeg: str) -> str:
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    text = (proc.stderr or "") + (proc.stdout or "")
    for line in text.splitlines():
        if "(audio)" not in line:
            continue
        m = re.search(r'"([^"]+)"', line)
        if m:
            return m.group(1)
    return ""


def write_wav(path: Path, pcm: bytes, sample_rate: int = 16000, channels: int = 1) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm)


def main() -> int:
    parser = argparse.ArgumentParser(description="Record microphone to WAV")
    parser.add_argument("--output", required=True, help="Output .wav path")
    parser.add_argument("--device", default="", help="dshow audio device name; empty = first audio device")
    parser.add_argument("--sample-rate", type=int, default=16000)
    parser.add_argument("--max-seconds", type=float, default=600.0, help="Safety cap for recording length")
    parser.add_argument(
        "--stop-file",
        default="",
        help="When this file appears, recording stops (for AHK / parent control)",
    )
    args = parser.parse_args()

    out = Path(args.output)
    stop_path = Path(args.stop_file.strip()) if args.stop_file.strip() else None
    if stop_path and stop_path.exists():
        try:
            stop_path.unlink()
        except OSError:
            pass
    ffmpeg = find_ffmpeg()
    device = args.device.strip() or first_dshow_audio_device(ffmpeg)
    if not device:
        print("error: no dshow audio device found", file=sys.stderr)
        return 2

    cmd = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "dshow",
        "-i",
        f"audio={device}",
        "-ac",
        "1",
        "-ar",
        str(args.sample_rate),
        "-t",
        str(max(1.0, args.max_seconds)),
        "-f",
        "s16le",
        "-",
    ]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    chunks: list[bytes] = []
    stop_flag = threading.Event()

    def _stop(*_a: object) -> None:
        stop_flag.set()
        try:
            proc.terminate()
        except Exception:
            pass

    def _watch_stop_file() -> None:
        if not stop_path:
            return
        while not stop_flag.is_set():
            if stop_path.exists():
                _stop()
                return
            time.sleep(0.12)

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    if stop_path:
        threading.Thread(target=_watch_stop_file, daemon=True).start()

    try:
        assert proc.stdout is not None
        while not stop_flag.is_set():
            block = proc.stdout.read(8192)
            if not block:
                break
            chunks.append(block)
    finally:
        stop_flag.set()
        try:
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        if stop_path and stop_path.exists():
            try:
                stop_path.unlink()
            except OSError:
                pass

    pcm = b"".join(chunks)
    if len(pcm) < 3200:
        print("error: recording too short or empty", file=sys.stderr)
        return 3

    write_wav(out, pcm, sample_rate=args.sample_rate)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
