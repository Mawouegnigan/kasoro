"""
Transcription MMS-1b-all (Meta) pour les langues peu dotees (fon).

Le modele est charge une seule fois, a la premiere utilisation, puis garde
en memoire. Utilise par pipeline.transcribe_audio quand language == "fon".
Utilise le GPU s'il existe, sinon le processeur.
"""
import os
import subprocess
import tempfile
import threading
import time
import wave

import numpy as np
import torch
from transformers import AutoProcessor, Wav2Vec2ForCTC

MODEL_ID = "facebook/mms-1b-all"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Une entree par langue : (processor, model)
_MMS_ASR = {}
_LOCK = threading.Lock()


def _charger_audio(chemin):
    """Convertit n'importe quel audio en mono 16 kHz via ffmpeg (float32)."""
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


def _obtenir_modele(langue):
    with _LOCK:
        if langue not in _MMS_ASR:
            print(f"    -> Chargement de {MODEL_ID} (langue : {langue}, appareil : {DEVICE}) ...")
            t0 = time.time()
            processor = AutoProcessor.from_pretrained(MODEL_ID, target_lang=langue)
            model = Wav2Vec2ForCTC.from_pretrained(
                MODEL_ID, target_lang=langue, ignore_mismatched_sizes=True
            )
            model.eval()
            model.to(DEVICE)
            _MMS_ASR[langue] = (processor, model)
            print(f"    -> Modele MMS charge en {time.time() - t0:.1f} s")
        return _MMS_ASR[langue]


def transcribe_mms(audio_path, language="fon"):
    """Retourne {"text": ..., "language": ...}, meme format que Whisper."""
    processor, model = _obtenir_modele(language)

    audio = _charger_audio(audio_path)
    duree = len(audio) / 16000
    if duree < 0.3:
        return {"text": "", "language": language}

    t0 = time.time()
    entrees = processor(audio, sampling_rate=16000, return_tensors="pt")
    entrees = {k: v.to(DEVICE) for k, v in entrees.items()}
    with torch.inference_mode():
        logits = model(**entrees).logits
    ids = torch.argmax(logits, dim=-1)[0]
    texte = processor.decode(ids).strip()

    print(f"    -> MMS : audio {duree:.1f} s, transcription {time.time() - t0:.1f} s")
    print(f"    -> Texte : {texte}")
    return {"text": texte, "language": language}