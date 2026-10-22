"""Gera os áudios (voz neural Kokoro) das palavras e frases de exemplo.

Uso:
    python tool/generate_audio.py --model kokoro-v1.0.onnx --voices voices-v1.0.bin

Requer: pip install kokoro-onnx soundfile, e ffmpeg no PATH.
Modelos: https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0).

Os arquivos são salvos em web/audio/words/<slug>.mp3 e web/audio/sentences/<slug>.mp3.
Arquivos já existentes são pulados; use --force para gerar tudo de novo.
Para acelerar, rode vários processos com --shard 0/4, 1/4, 2/4, 3/4.
"""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parent.parent
WORDS_FILE = ROOT / "assets" / "words.txt"
OUT_DIR = ROOT / "web" / "audio"


def slug(word: str) -> str:
    """Mesmo cálculo de Word.audioSlug no app."""
    return re.sub(r"[^a-z0-9]+", "_", word.lower()).strip("_")


def to_mp3(samples, sample_rate: int, target: Path) -> None:
    with tempfile.NamedTemporaryFile(suffix=".wav") as wav:
        sf.write(wav.name, samples, sample_rate)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav.name,
             "-ac", "1", "-codec:a", "libmp3lame", "-b:a", "48k", str(target)],
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--voices", required=True)
    parser.add_argument("--voice", default="af_heart")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--shard", default="0/1", help="k/n: processa só as linhas i %% n == k (para rodar em paralelo)")
    args = parser.parse_args()

    kokoro = Kokoro(args.model, args.voices)
    (OUT_DIR / "words").mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "sentences").mkdir(parents=True, exist_ok=True)

    lines = [l for l in WORDS_FILE.read_text(encoding="utf-8").splitlines() if l.strip()]
    shard, shards = map(int, args.shard.split("/"))
    for i, line in enumerate(lines, 1):
        if i % shards != shard:
            continue
        word, _pos, _pt, example_en, _example_pt = line.split("|")
        jobs = [
            (OUT_DIR / "words" / f"{slug(word)}.mp3", word, 0.85),
            (OUT_DIR / "sentences" / f"{slug(word)}.mp3", example_en, 0.95),
        ]
        for target, text, speed in jobs:
            if target.exists() and not args.force:
                continue
            samples, sample_rate = kokoro.create(text, voice=args.voice, speed=speed, lang="en-us")
            to_mp3(samples, sample_rate, target)
        if i % 100 == 0:
            print(f"{i}/{len(lines)}", flush=True)
    print("ok", file=sys.stderr)


if __name__ == "__main__":
    main()
