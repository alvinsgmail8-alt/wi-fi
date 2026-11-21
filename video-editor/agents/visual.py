"""Visual agent: stabilization, color correction, vertical (9:16) reframing."""
from __future__ import annotations

import tempfile
from pathlib import Path

from .common import ffmpeg


def process(src: str | Path, out: str | Path, stabilize: bool = False, color: bool = False,
            vertical: bool = False) -> Path:
    src, out = Path(src), Path(out)
    if not (stabilize or color or vertical):
        ffmpeg("-i", str(src), "-c", "copy", str(out))
        return out

    with tempfile.TemporaryDirectory() as tmp:
        filters = []
        if stabilize:
            trf = Path(tmp) / "transforms.trf"
            ffmpeg("-i", str(src), "-vf", f"vidstabdetect=shakiness=6:result={trf}", "-f", "null", "-")
            filters += [f"vidstabtransform=input={trf}:smoothing=20", "unsharp=5:5:0.6"]
        if color:
            filters.append("eq=contrast=1.06:saturation=1.15:gamma=1.02")
        if vertical:
            filters += ["crop=ih*9/16:ih", "scale=1080:1920:flags=lanczos", "setsar=1"]
        ffmpeg("-i", str(src), "-vf", ",".join(filters), "-c:v", "libx264", "-preset", "medium",
               "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "copy", str(out))
    return out
