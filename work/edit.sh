#!/usr/bin/env bash
# Instagram Reel edit of the alpine coaster ride.
set -euo pipefail
cd "$(dirname "$0")"
SRC=input.mov
mkdir -p seg

# start  end   speed   (source seconds)
SEGMENTS="
36.0 39.5 1.0
4.5  8.5  1.5
9.0  14.0 1.5
18.0 24.0 1.25
28.0 35.0 1.5
44.0 47.0 1.0
54.0 58.0 1.0
72.0 79.0 2.0
83.0 90.0 1.5
"

render() {
  local i=$1 s=$2 e=$3 sp=$4
  ffmpeg -hide_banner -loglevel error -y -ss "$s" -t "$(echo "$e - $s" | bc)" -i "$SRC" \
    -vf "scale=1080:1920:flags=lanczos,setpts=PTS/$sp,fps=60,setsar=1" \
    -af "atempo=$sp,aresample=48000" \
    -c:v libx264 -preset veryfast -crf 14 -pix_fmt yuv420p -c:a pcm_s16le \
    "seg/$(printf %02d "$i").mov"
}
export -f render
export SRC

i=0
echo "$SEGMENTS" | while read -r s e sp; do
  [ -z "$s" ] && continue
  echo "$i $s $e $sp"; i=$((i+1))
done | xargs -P 2 -L 1 bash -c 'render "$0" "$1" "$2" "$3"'
ls seg
