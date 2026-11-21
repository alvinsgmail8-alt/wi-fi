#!/usr/bin/env bash
# Full ride Reel: hook -> lift up the mountain -> top panorama -> descent. No text, no music.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p seg2

# file            start end  speed
CLIMB="
clips/clip3.mov    2.0  8.0  3.0
clips/clip3.mov   30.0 42.0  4.0
clips/clip3.mov   63.0 71.0  1.5
clips/clip2.mov   16.0 24.0  1.25
clips/clip1.mov   28.0 33.0  2.0
"

render() {
  local i=$1 src=$2 s=$3 e=$4 sp=$5
  ffmpeg -hide_banner -loglevel error -y -ss "$s" -t "$(echo "$e - $s" | bc)" -i "$src" -an \
    -vf "scale=1080:1920:flags=lanczos,setpts=PTS/$sp,fps=60,setsar=1" \
    -c:v libx264 -preset veryfast -crf 14 -pix_fmt yuv420p "seg2/$(printf %02d "$i").mov"
}
export -f render

i=0
echo "$CLIMB" | while read -r src s e sp; do
  [ -z "$src" ] && continue
  echo "$i $src $s $e $sp"; i=$((i+1))
done | xargs -P 2 -L 1 bash -c 'render "$0" "$1" "$2" "$3" "$4"'
