#!/usr/bin/env bash
# Joins the rendered segments into the final Instagram Reel.
set -euo pipefail
cd "$(dirname "$0")"
printf "POV:" > t1.txt
printf "tog'lar bag'rida" > t2.txt
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf

IN=(); FC=""; L=""; N=0
for f in seg/*.mov; do
  IN+=(-i "$f")
  FC+="[$N:a]afade=t=in:d=0.04,areverse,afade=t=in:d=0.04,areverse[a$N];"
  L+="[$N:v][a$N]"; N=$((N+1))
done
TOTAL=$(for f in seg/*.mov; do ffprobe -v error -show_entries format=duration -of csv=p=0 "$f"; done | paste -sd+ | bc)
FS=$(echo "$TOTAL - 0.6" | bc)
ALPHA="if(lt(t,0.2),0,if(lt(t,0.5),(t-0.2)/0.3,if(lt(t,2.6),1,if(lt(t,3.0),(3.0-t)/0.4,0))))"
TEXT="fontfile=$FONT:fontcolor=white:shadowcolor=black@0.55:shadowx=4:shadowy=4:x=(w-text_w)/2:alpha='$ALPHA'"

FC+="${L}concat=n=$N:v=1:a=1[cv][ca];"
FC+="[cv]vibrance=intensity=0.22,eq=contrast=1.07:saturation=1.06:gamma=0.98,"
FC+="colorbalance=rs=0.02:bs=-0.02:rh=0.02:bh=-0.03,unsharp=5:5:0.4,"
FC+="drawtext=textfile=t1.txt:fontsize=110:y=h*0.18:$TEXT,"
FC+="drawtext=textfile=t2.txt:fontsize=78:y=h*0.18+135:$TEXT,"
FC+="fade=t=out:st=$FS:d=0.6[v];"
FC+="[ca]highpass=f=60,loudnorm=I=-18:TP=-2:LRA=11,afade=t=out:st=$FS:d=0.6,aresample=48000[a]"

ffmpeg -hide_banner -loglevel error -y "${IN[@]}" -filter_complex "$FC" -map "[v]" -map "[a]" \
  -map_metadata -1 -c:v libx264 -preset slow -crf 19 -maxrate 16M -bufsize 32M \
  -profile:v high -level 4.2 -pix_fmt yuv420p -r 60 -g 120 \
  -c:a aac -b:a 256k -movflags +faststart reel_instagram.mp4
