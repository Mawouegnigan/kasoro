"""
Banc d'essai : transcription MMS-1b-all (Meta) pour une langue peu dotee.

Lancement (depuis backend\) :
  docker compose exec -w /code/pipeline api python bench_asr_mms.py FICHIER [FICHIER ...] [--lang fon]

Charge le modele une seule fois, puis transcrit chaque fichier et mesure le temps.
"""
import os
import subprocess
import sys
import tempfile
import time
import wave

import numpy as np
import torch
from transformers import AutoProcessor, Wav2Vec2ForCTC

MODEL_ID = "facebook/mms-1b-all"


def charger_audio(chemin):
    """Convertit n'importe quel audio en mono 16 kHz via ffmpeg, retourne un tableau float32."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-i", chemin, "-ac", "1", "-ar", "16000", wav_path],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        with wave.open(wav_path, "rb") as w:
            brut = w.readframes(w.getnframes())
        return np.frombuffer(brut, dtype=np.int16).astype(np.float32) / 32768.0
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)


def main():
    args = sys.argv[1:]
    langue = "fon"
    if "--lang" in args:
        i = args.index("--lang")
        langue = args[i + 1]
        del args[i : i + 2]
    fichiers = args
    if not fichiers:
        print("Usage : python bench_asr_mms.py FICHIER [FICHIER ...] [--lang fon]")
        return

    torch.set_num_threads(4)

    print(f"Chargement de {MODEL_ID} (langue : {langue}) ...")
    t0 = time.time()
    processor = AutoProcessor.from_pretrained(MODEL_ID, target_lang=langue)
    model = Wav2Vec2ForCTC.from_pretrained(
        MODEL_ID, target_lang=langue, ignore_mismatched_sizes=True
    )
    model.eval()
    print(f"Modele charge en {time.time() - t0:.1f} s")

    for chemin in fichiers:
        print(f"\n--- {chemin}")
        audio = charger_audio(chemin)
        duree = len(audio) / 16000
        t1 = time.time()
        entrees = processor(audio, sampling_rate=16000, return_tensors="pt")
        with torch.inference_mode():
            logits = model(**entrees).logits
        ids = torch.argmax(logits, dim=-1)[0]
        texte = processor.decode(ids)
        print(f"Audio : {duree:.1f} s | Transcription : {time.time() - t1:.1f} s")
        print(f"Texte : {texte}")


if __name__ == "__main__":
    main()