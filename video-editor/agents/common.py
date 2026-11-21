"""Shared helpers: running ffmpeg/ffprobe and the edit-decision-list (EDL) type."""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from pydantic import BaseModel, Field


class Segment(BaseModel):
    start: float = Field(description="Segment start, in seconds")
    end: float = Field(description="Segment end, in seconds")
    note: str = Field(default="", description="Why this part is kept")


class EditPlan(BaseModel):
    segments: list[Segment] = Field(description="Parts to keep, in output order")
    summary: str = Field(default="", description="Short explanation of the edit")


def require(binary: str) -> None:
    if shutil.which(binary) is None:
        raise SystemExit(f"'{binary}' topilmadi. Uni o'rnating.")


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    """Run a command, raising with its stderr on failure."""
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Buyruq xato bilan tugadi: {' '.join(cmd)}\n{proc.stderr[-2000:]}")
    return proc


def ffmpeg(*args: str) -> subprocess.CompletedProcess:
    require("ffmpeg")
    return run(["ffmpeg", "-hide_banner", "-y", *args])


def probe(path: str | Path) -> dict:
    require("ffprobe")
    out = run(["ffprobe", "-v", "error", "-print_format", "json",
               "-show_format", "-show_streams", str(path)]).stdout
    return json.loads(out)


def duration(path: str | Path) -> float:
    return float(probe(path)["format"]["duration"])


def has_audio(path: str | Path) -> bool:
    return any(s["codec_type"] == "audio" for s in probe(path)["streams"])


def video_stream(path: str | Path) -> dict:
    return next(s for s in probe(path)["streams"] if s["codec_type"] == "video")


def rotation(stream: dict) -> int:
    for side in stream.get("side_data_list", []):
        if "rotation" in side:
            return int(side["rotation"]) % 360
    return int(stream.get("tags", {}).get("rotate", 0)) % 360


def display_size(path: str | Path) -> tuple[int, int]:
    """Width/height as the video is shown (phones store portrait clips rotated)."""
    v = video_stream(path)
    w, h = int(v["width"]), int(v["height"])
    return (h, w) if rotation(v) in (90, 270) else (w, h)


def is_hdr(path: str | Path) -> bool:
    return video_stream(path).get("color_transfer") in ("arib-std-b67", "smpte2084")


# Shared x264 settings for every encode, tuned for social media upload.
X264 = ["-c:v", "libx264", "-preset", "fast", "-crf", "18", "-profile:v", "high",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart"]
