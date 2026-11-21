"""Run all video editing agents in order.

Example:
    python pipeline.py input.mp4 -o output.mp4 --prompt "Make a tight 60-second cut" --vertical
"""
from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

from agents import analyzer, audio, cutter, planner, qa, transcriber, visual
from agents.common import duration


def main() -> None:
    p = argparse.ArgumentParser(description="Videoni avtomatik tahrirlash")
    p.add_argument("input")
    p.add_argument("-o", "--output", default="output.mp4")
    p.add_argument("--prompt", default="Remove pauses, filler words and mistakes; keep the story clear.",
                   help="Planner uchun ko'rsatma")
    p.add_argument("--language", default=None, help="Nutq tili, masalan uz, ru, en (bo'sh = avto)")
    p.add_argument("--whisper-model", default="small")
    p.add_argument("--no-claude", action="store_true", help="Claude o'rniga oddiy qoidani ishlatish")
    p.add_argument("--no-denoise", action="store_true")
    p.add_argument("--voice-only", action="store_true", help="Demucs bilan faqat ovozni qoldirish")
    p.add_argument("--music", help="Fon musiqasi fayli")
    p.add_argument("--stabilize", action="store_true")
    p.add_argument("--color", action="store_true")
    p.add_argument("--vertical", action="store_true", help="9:16 (Reels/Shorts) formatga o'tkazish")
    args = p.parse_args()

    src, out = Path(args.input), Path(args.output)
    report_path = out.with_suffix(".report.json")

    print("1/7 Analyzer...")
    info = analyzer.analyze(src)

    print("2/7 Transcriber...")
    transcript = transcriber.transcribe(src, args.whisper_model, args.language) if info["has_audio"] else []

    print("3/7 Planner...")
    edit = planner.plan(info, transcript, args.prompt, use_claude=not args.no_claude)
    print(f"    {len(edit.segments)} ta segment. {edit.summary}")

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        print("4/7 Cutter...")
        cut = cutter.render(src, edit, tmp / "cut.mp4")

        print("5/7 Audio...")
        mixed = audio.process(cut, tmp / "audio.mp4", denoise=not args.no_denoise,
                              voice_only=args.voice_only, music=args.music)

        print("6/7 Visual...")
        visual.process(mixed, out, stabilize=args.stabilize, color=args.color, vertical=args.vertical)

    print("7/7 QA...")
    expected = sum(s.end - s.start for s in edit.segments)
    result = qa.check(out, expected_duration=expected)

    report_path.write_text(json.dumps({
        "input": str(src), "input_duration": info["duration"], "output": str(out),
        "output_duration": duration(out), "plan": edit.model_dump(), "qa": result,
        "transcript": transcript,
    }, ensure_ascii=False, indent=2))

    print(f"\nTayyor: {out}  ({info['duration']:.1f}s -> {result['duration']:.1f}s)")
    print("QA: OK" if result["ok"] else "QA muammolari:\n  - " + "\n  - ".join(result["problems"]))
    print(f"Hisobot: {report_path}")


if __name__ == "__main__":
    main()
