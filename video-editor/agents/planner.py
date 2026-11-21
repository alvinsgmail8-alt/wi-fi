"""Planner agent: decides which parts to keep.

Uses Claude when API credentials are available, otherwise a simple rule:
keep everything except long silences.
"""
from __future__ import annotations

import json

from .common import EditPlan, Segment

MODEL = "claude-opus-5-5"

SYSTEM = (
    "You are a professional video editor. You get a video's analysis (duration, scene cuts, "
    "silences) and its transcript with timestamps. Return the segments to keep, in output "
    "order, so the result follows the user's instructions. Cut filler, long pauses, false "
    "starts and repeated takes. Start and end cuts at sentence boundaries, never mid-word. "
    "Segments must lie within the video's duration and must not overlap."
)


def heuristic_plan(analysis: dict, pad: float = 0.15) -> EditPlan:
    """Keep everything between silences, with a little padding."""
    total = analysis["duration"]
    keep, cursor = [], 0.0
    for start, end in analysis["silences"]:
        end = total if end is None else end
        if start - cursor > 0.3:
            keep.append(Segment(start=max(0.0, cursor - pad), end=min(total, start + pad)))
        cursor = end
    if total - cursor > 0.3:
        keep.append(Segment(start=max(0.0, cursor - pad), end=total))
    if not keep:
        keep = [Segment(start=0.0, end=total)]
    return EditPlan(segments=keep, summary="Uzun jim joylar olib tashlandi (Claude'siz rejim).")


def claude_plan(analysis: dict, transcript: list[dict], instructions: str) -> EditPlan:
    import anthropic

    client = anthropic.Anthropic()
    payload = {"analysis": analysis, "transcript": transcript}
    response = client.beta.messages.parse(
        model=MODEL,
        max_tokens=16000,
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        output_config={"effort": "high"},
        system=SYSTEM,
        messages=[{
            "role": "user",
            "content": f"Instructions: {instructions}\n\nVideo data:\n{json.dumps(payload, ensure_ascii=False)}",
        }],
        output_format=EditPlan,
    )
    if response.stop_reason == "refusal" or response.parsed_output is None:
        raise RuntimeError(f"Claude reja bermadi (stop_reason={response.stop_reason}).")
    return response.parsed_output


def clean(plan: EditPlan, total: float) -> EditPlan:
    """Clamp segments to the video and drop empty ones."""
    segs = []
    for s in plan.segments:
        start, end = max(0.0, s.start), min(total, s.end)
        if end - start >= 0.1:
            segs.append(Segment(start=start, end=end, note=s.note))
    if not segs:
        raise RuntimeError("Rejada birorta ham segment qolmadi.")
    return EditPlan(segments=segs, summary=plan.summary)


def plan(analysis: dict, transcript: list[dict], instructions: str, use_claude: bool = True) -> EditPlan:
    result = None
    if use_claude:
        import anthropic

        try:
            result = claude_plan(analysis, transcript, instructions)
        except (anthropic.AuthenticationError, anthropic.PermissionDeniedError) as exc:
            print(f"[planner] Claude API kaliti topilmadi ({exc.__class__.__name__}); oddiy rejimga o'tildi.")
        except anthropic.APIConnectionError as exc:
            print(f"[planner] Claude API'ga ulanib bo'lmadi ({exc}); oddiy rejimga o'tildi.")
        except TypeError as exc:  # no credentials configured at all
            print(f"[planner] Claude sozlanmagan ({exc}); oddiy rejimga o'tildi.")
    if result is None:
        result = heuristic_plan(analysis)
    return clean(result, analysis["duration"])
