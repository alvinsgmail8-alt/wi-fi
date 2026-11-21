"""Audio agent: denoise, voice isolation (Demucs), background music, loudness."""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from .common import ffmpeg, has_audio


def isolate_voice(src: Path, workdir: Path) -> Path:
    """Separate the voice from background noise/music with Demucs."""
    subprocess.run([sys.executable, "-m", "demucs", "-n", "htdemucs", "--two-stems=vocals",
                    "-o", str(workdir), str(src)], check=True, capture_output=True)
    return workdir / "htdemucs" / src.stem / "vocals.wav"


def process(src: str | Path, out: str | Path, denoise: bool = True, voice_only: bool = False,
            music: str | Path | None = None, music_db: float = -18.0) -> Path:
    src, out = Path(src), Path(out)
    if not has_audio(src):
        ffmpeg("-i", str(src), "-c", "copy", str(out))
        return out

    with tempfile.TemporaryDirectory() as tmp:
        inputs = ["-i", str(src)]
        voice = "[0:a]"
        if voice_only:
            inputs += ["-i", str(isolate_voice(src, Path(tmp)))]
            voice = "[1:a]"

        chain = []
        if denoise:
            chain.append("afftdn=nf=-25")
        chain.append("highpass=f=80")
        filters = [f"{voice}{','.join(chain)}[voice]"]
        mix = "[voice]"

        if music:
            idx = len(inputs) // 2
            inputs += ["-stream_loop", "-1", "-i", str(music)]
            # Music gets quieter automatically while someone speaks (ducking).
            filters += [
                "[voice]asplit=2[vmain][vkey]",
                f"[{idx}:a]volume={music_db}dB[bg]",
                "[bg][vkey]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[ducked]",
                "[vmain][ducked]amix=inputs=2:duration=first:dropout_transition=0[mix]",
            ]
            mix = "[mix]"

        filters.append(f"{mix}loudnorm=I=-14:TP=-1.5:LRA=11[aout]")
        ffmpeg(*inputs, "-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[aout]",
               "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", str(out))
    return out
