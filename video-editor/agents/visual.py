"""Visual agent: HDR to SDR, framing/resolution, stabilization, color correction."""
from __future__ import annotations

import tempfile
from pathlib import Path

from .common import X264, display_size, ffmpeg, is_hdr

# iPhone HDR (HLG / Dolby Vision) to normal SDR, so colors don't look washed out on Instagram.
TONEMAP = ("zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,"
           "tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p")


def geometry_filters(src: str | Path, vertical: bool = False, height: int | None = 1080,
                     fps: float | None = None) -> list[str]:
    """Filters applied while cutting, so the 4K source is decoded and encoded only once.

    Cropping to 9:16 happens before scaling down, so no detail is lost.
    """
    filters = []
    w, h = display_size(src)
    if vertical:
        if w / h > 9 / 16 + 0.01:
            filters.append("crop=trunc(ih*9/16/2)*2:ih")
        elif w / h < 9 / 16 - 0.01:
            filters.append("crop=iw:trunc(iw*16/9/2)*2")
        short = min(w, h * 9 // 16)
        target = min(height or short, short)
        filters.append(f"scale={target // 2 * 2}:{round(target * 16 / 9 / 2) * 2}:flags=lanczos")
    elif height and min(w, h) > height:
        filters.append((f"scale=-2:{height}" if w >= h else f"scale={height}:-2") + ":flags=lanczos")
    # Tone-map after downscaling: same look, several times faster than at 4K.
    if is_hdr(src):
        filters.append(TONEMAP)
    filters.append("setsar=1")
    if fps:
        filters.append(f"fps={fps}")
    return filters


def process(src: str | Path, out: str | Path, stabilize: bool = False, color: bool = False) -> Path:
    src, out = Path(src), Path(out)
    if not (stabilize or color):
        ffmpeg("-i", str(src), "-c", "copy", "-movflags", "+faststart", str(out))
        return out

    with tempfile.TemporaryDirectory() as tmp:
        filters = []
        if stabilize:
            trf = Path(tmp) / "transforms.trf"
            ffmpeg("-i", str(src), "-vf", f"vidstabdetect=shakiness=6:result={trf}", "-f", "null", "-")
            filters += [f"vidstabtransform=input={trf}:smoothing=20:zoom=2", "unsharp=5:5:0.5"]
        if color:
            # Light, natural "Instagram" look: a bit more contrast and color, slight sharpening.
            filters += ["eq=contrast=1.06:saturation=1.18:gamma=1.02", "unsharp=3:3:0.3"]
        ffmpeg("-i", str(src), "-vf", ",".join(filters), *X264, "-c:a", "copy", str(out))
    return out
