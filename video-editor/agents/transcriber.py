"""Transcriber agent: speech to text with word timestamps (faster-whisper)."""
from __future__ import annotations

from pathlib import Path


def transcribe(path: str | Path, model_size: str = "small", language: str | None = None) -> list[dict]:
    from faster_whisper import WhisperModel

    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(str(path), language=language, word_timestamps=True,
                                       vad_filter=True)
    return [
        {"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()}
        for s in segments
    ]
