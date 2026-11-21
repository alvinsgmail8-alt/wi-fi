# Video Editor agentlari

Videoni avtomatik tahrirlaydigan 7 ta agent (subtitrsiz):

| # | Agent | Fayl | Nima qiladi | Asbob |
|---|-------|------|-------------|-------|
| 1 | Analyzer | `agents/analyzer.py` | Video ma'lumotlari, sahnalar, jim joylar | ffprobe, PySceneDetect |
| 2 | Transcriber | `agents/transcriber.py` | Nutqni vaqt belgilari bilan matnga aylantiradi | faster-whisper |
| 3 | Planner | `agents/planner.py` | Nimani qoldirish va kesishni hal qiladi | Claude API (yoki oddiy qoida) |
| 4 | Cutter | `agents/cutter.py` | Kesadi va birlashtiradi | ffmpeg |
| 5 | Audio | `agents/audio.py` | Shovqinni tozalaydi, ovozni ajratadi, musiqa qo'shadi, ovoz balandligini tenglaydi | ffmpeg, Demucs |
| 6 | Visual | `agents/visual.py` | Stabilizatsiya, rang, 9:16 format | ffmpeg (vidstab) |
| 7 | QA | `agents/qa.py` | Davomiylik, A/V sinxronligi va qora kadrlarni tekshiradi | ffprobe, ffmpeg |

## O'rnatish

```bash
./install.sh
```

## Ishlatish

```bash
. .venv/bin/activate
python pipeline.py video.mp4 -o natija.mp4 --prompt "60 soniyalik qisqa versiya qil" --language uz
```

Qo'shimcha parametrlar:

- `--vertical`: 9:16 formatga o'tkazadi (Reels yoki Shorts uchun)
- `--stabilize`: titrayotgan videoni barqarorlashtiradi
- `--color`: rangni biroz jonlantiradi
- `--music fon.mp3`: fon musiqasini qo'shadi (gapirilganda musiqa avtomatik pasayadi)
- `--voice-only`: Demucs bilan faqat ovozni qoldiradi (fon shovqini yo'qoladi)
- `--no-claude`: Claude o'rniga oddiy qoidani ishlatadi (faqat jim joylarni kesadi)

Har ishga tushirishdan keyin `natija.report.json` fayli yaratiladi. Unda reja, transkript va QA natijasi bo'ladi.

## Claude (Planner) uchun

Aqlli kesish uchun Anthropic API kaliti kerak:

```bash
export ANTHROPIC_API_KEY=...
```

Kalit bo'lmasa, Planner avtomatik ravishda oddiy rejimga o'tadi: faqat uzun jim joylarni kesadi.
