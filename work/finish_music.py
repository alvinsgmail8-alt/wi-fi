"""Final Reel with music instead of the original sound.

Usage:
    python finish_music.py MUSIC.mp3 OUT.mp4 [sync.json]

With sync.json ({"offset": s, "durs": [...]}) every segment is trimmed so each cut
lands on a beat. Without it, segments keep their length and the music starts at 0.
"""
import glob
import json
import subprocess
import sys

music, out = sys.argv[1], sys.argv[2]
segs = sorted(glob.glob("seg/*.mov"))
probe = lambda f: float(subprocess.check_output(
    ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f]))
if len(sys.argv) > 3:
    sync = json.load(open(sys.argv[3]))
    offset, durs = sync["offset"], sync["durs"]
else:
    offset, durs = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0, [probe(f) for f in segs]

total = sum(durs)
font = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
alpha = "if(lt(t,0.2),0,if(lt(t,0.5),(t-0.2)/0.3,if(lt(t,2.6),1,if(lt(t,3.0),(3.0-t)/0.4,0))))"
text = (f"fontfile={font}:fontcolor=white:shadowcolor=black@0.55:shadowx=4:shadowy=4:"
        f"x=(w-text_w)/2:alpha='{alpha}'")

inputs, fc, labels = [], [], ""
for i, (f, d) in enumerate(zip(segs, durs)):
    inputs += ["-i", f]
    fc.append(f"[{i}:v]trim=duration={d:.4f},setpts=PTS-STARTPTS[v{i}]")
    labels += f"[v{i}]"
m = len(segs)
inputs += ["-ss", f"{offset:.3f}", "-i", music]
fc.append(f"{labels}concat=n={m}:v=1:a=0[cv]")
fc.append(
    "[cv]vibrance=intensity=0.22,eq=contrast=1.07:saturation=1.06:gamma=0.98,"
    "colorbalance=rs=0.02:bs=-0.02:rh=0.02:bh=-0.03,unsharp=5:5:0.4,"
    f"drawtext=textfile=t1.txt:fontsize=110:y=h*0.18:{text},"
    f"drawtext=textfile=t2.txt:fontsize=78:y=h*0.18+135:{text},"
    f"fade=t=out:st={total - 0.6:.3f}:d=0.6[v]")
fc.append(
    f"[{m}:a]atrim=duration={total:.4f},asetpts=PTS-STARTPTS,afade=t=in:d=0.03,"
    f"afade=t=out:st={total - 1.8:.3f}:d=1.8,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]")

subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
                "-filter_complex", ";".join(fc), "-map", "[v]", "-map", "[a]", "-map_metadata", "-1",
                "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-maxrate", "16M", "-bufsize", "32M",
                "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p", "-r", "60", "-g", "120",
                "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", out], check=True)
print(f"{out}: {total:.2f}s")
