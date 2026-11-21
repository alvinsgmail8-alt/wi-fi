"""Analyzer agent: video metadata, scene cuts and silent stretches."""
from __future__ import annotations

import re
import tempfile
from pathlib import Path

from .common import ffmpeg, has_audio, probe


def detect_scenes(path: str | Path, threshold: float = 27.0) -> list[tuple[float, float]]:
    """Find scene cuts on a small 360p proxy: same cuts, much faster on 4K footage."""
    from scenedetect import ContentDetector, detect

    with tempfile.TemporaryDirectory() as tmp:
        proxy = Path(tmp) / "proxy.mp4"
        ffmpeg("-i", str(path), "-vf", "scale=-2:360,fps=30", "-an", "-c:v", "libx264",
               "-preset", "ultrafast", "-crf", "28", str(proxy))
        scenes = detect(str(proxy), ContentDetector(threshold=threshold))
    return [(round(s.get_seconds(), 3), round(e.get_seconds(), 3)) for s, e in scenes]


def detect_silences(path: str | Path, noise_db: int = -35, min_len: float = 0.6) -> list[tuple[float, float]]:
    if not has_audio(path):
        return []
    err = ffmpeg("-i", str(path), "-af", f"silencedetect=noise={noise_db}dB:d={min_len}",
                 "-f", "null", "-").stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
    return list(zip(starts, ends + [None] * (len(starts) - len(ends))))


def analyze(path: str | Path) -> dict:
    info = probe(path)
    video = next((s for s in info["streams"] if s["codec_type"] == "video"), {})
    num, _, den = video.get("r_frame_rate", "0/1").partition("/")
    return {
        "file": str(path),
        "duration": float(info["format"]["duration"]),
        "width": video.get("width"),
        "height": video.get("height"),
        "fps": round(float(num) / float(den or 1), 3),
        "has_audio": has_audio(path),
        "scenes": detect_scenes(path),
        "silences": detect_silences(path),
    }
