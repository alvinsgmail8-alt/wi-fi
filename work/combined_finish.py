"""Assemble the full-ride Reel: hook -> climb -> descent. No text, silent audio track."""
import subprocess

# (file, start within segment, duration or None for whole)
TIMELINE = [
    ("seg/00.mov", 0.0, 2.5),    # hook: lake and snowy peaks during the descent
    ("seg2/00.mov", 0.0, None),  # leaving the station
    ("seg2/01.mov", 0.0, None),  # climbing past the spiral track
    ("seg2/02.mov", 0.0, None),  # wooden tunnel
    ("seg2/03.mov", 0.5, 5.3),   # top panorama: mountains, valley, lake
    ("seg2/04.mov", 0.0, None),  # signs at the top, the drop is next
    ("seg/01.mov", 0.0, None),   # descent
    ("seg/02.mov", 0.0, None),
    ("seg/03.mov", 0.0, None),
    ("seg/04.mov", 0.0, None),
    ("seg/06.mov", 0.0, None),
    ("seg/07.mov", 0.0, None),
    ("seg/08.mov", 0.0, None),
]


def duration(f):
    return float(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f]))


inputs, fc, labels, total = [], [], "", 0.0
for i, (f, start, dur) in enumerate(TIMELINE):
    dur = dur or duration(f) - start
    total += dur
    inputs += ["-i", f]
    fc.append(f"[{i}:v]trim=start={start}:duration={dur:.4f},setpts=PTS-STARTPTS[v{i}]")
    labels += f"[v{i}]"
n = len(TIMELINE)
fc.append(f"{labels}concat=n={n}:v=1:a=0[cv]")
fc.append("[cv]vibrance=intensity=0.22,eq=contrast=1.07:saturation=1.06:gamma=0.98,"
          "colorbalance=rs=0.02:bs=-0.02:rh=0.02:bh=-0.03,unsharp=5:5:0.4,"
          f"fade=t=out:st={total - 0.6:.3f}:d=0.6[v]")

subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
                "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
                "-filter_complex", ";".join(fc), "-map", "[v]", "-map", f"{n}:a", "-shortest",
                "-map_metadata", "-1", "-c:v", "libx264", "-preset", "slow", "-crf", "19",
                "-maxrate", "16M", "-bufsize", "32M", "-profile:v", "high", "-level", "4.2",
                "-pix_fmt", "yuv420p", "-r", "60", "-g", "120", "-c:a", "aac", "-b:a", "128k",
                "-movflags", "+faststart", "reel_full_ride.mp4"], check=True)
print(f"reel_full_ride.mp4: {total:.2f}s")
