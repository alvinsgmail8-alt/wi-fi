#!/usr/bin/env bash
# Installs everything the video editing agents need.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v ffmpeg >/dev/null; then
  if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y ffmpeg
  elif command -v brew >/dev/null; then brew install ffmpeg
  else echo "ffmpeg'ni qo'lda o'rnating: https://ffmpeg.org/download.html"; exit 1; fi
fi

python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Download the models once so the first run is fast.
python -c "from faster_whisper import WhisperModel; WhisperModel('small', device='cpu', compute_type='int8')"
python -c "from demucs.pretrained import get_model; get_model('htdemucs')"
echo "Tayyor. Ishga tushirish: . .venv/bin/activate && python pipeline.py video.mp4 -o natija.mp4"
