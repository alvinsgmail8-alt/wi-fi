"""Cutter agent: renders the kept segments into one video with ffmpeg."""
from __future__ import annotations

from pathlib import Path

from .common import EditPlan, ffmpeg, has_audio


def render(src: str | Path, plan: EditPlan, out: str | Path, fade: float = 0.05) -> Path:
    audio = has_audio(src)
    parts, labels = [], []
    for i, s in enumerate(plan.segments):
        parts.append(f"[0:v]trim={s.start}:{s.end},setpts=PTS-STARTPTS[v{i}]")
        labels.append(f"[v{i}]")
        if audio:
            d = s.end - s.start
            f = min(fade, d / 4)
            parts.append(
                f"[0:a]atrim={s.start}:{s.end},asetpts=PTS-STARTPTS,"
                f"afade=t=in:d={f},afade=t=out:st={d - f}:d={f}[a{i}]"
            )
            labels.append(f"[a{i}]")
    n = len(plan.segments)
    parts.append(f"{''.join(labels)}concat=n={n}:v=1:a={1 if audio else 0}[v]" + ("[a]" if audio else ""))

    args = ["-i", str(src), "-filter_complex", ";".join(parts), "-map", "[v]"]
    if audio:
        args += ["-map", "[a]", "-c:a", "aac", "-b:a", "192k"]
    args += ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", str(out)]
    ffmpeg(*args)
    return Path(out)
