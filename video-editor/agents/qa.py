"""QA agent: checks the finished video for common problems."""
from __future__ import annotations

import re
from pathlib import Path

from .common import ffmpeg, probe


def check(path: str | Path, expected_duration: float | None = None) -> dict:
    info = probe(path)
    streams = {s["codec_type"]: s for s in info["streams"]}
    total = float(info["format"]["duration"])
    problems = []

    if "video" not in streams:
        problems.append("Video oqimi yo'q")
    if expected_duration and abs(total - expected_duration) > 0.5:
        problems.append(f"Davomiylik {total:.2f}s, kutilgan {expected_duration:.2f}s")

    if "audio" in streams and "video" in streams:
        a = float(streams["audio"].get("duration", total))
        v = float(streams["video"].get("duration", total))
        if abs(a - v) > 0.2:
            problems.append(f"Audio/video uzunligi farq qiladi: {a:.2f}s va {v:.2f}s")

    err = ffmpeg("-i", str(path), "-vf", "blackdetect=d=0.5:pix_th=0.10", "-an", "-f", "null", "-").stderr
    blacks = re.findall(r"black_start:([\d.]+) black_end:([\d.]+)", err)
    if blacks:
        problems.append(f"Qora kadrlar: {[(float(s), float(e)) for s, e in blacks]}")

    return {"file": str(path), "duration": round(total, 2), "ok": not problems, "problems": problems}
