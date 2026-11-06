"""Service GPU Kasoro : expose transcription, traduction et voix par HTTP.

Il enveloppe les fonctions du dossier pipeline/ (sans les modifier) pour que
l'API du VPS les appelle par HTTP au lieu de charger les modèles elle-même.

Variables d'environnement :
  GPU_API_KEY    clé secrète partagée avec l'API du VPS (16 caractères minimum)
  PRELOAD_VOIX   langues de voix à précharger, séparées par des virgules
                 (par défaut : fr,en,yo,fon)
"""
import os
import secrets
import sys
import tempfile
import threading
from contextlib import asynccontextmanager
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "pipeline"))

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel
from starlette.background import BackgroundTask

import pipeline as kasoro_pipeline
from nllb_translator import TraductionIndisponible

CLE = os.environ.get("GPU_API_KEY", "")
if len(CLE) < 16:
    raise RuntimeError("GPU_API_KEY manquante ou trop courte (16 caractères minimum)")

LANGUES_VOIX = [
    l.strip() for l in os.environ.get("PRELOAD_VOIX", "fr,en,yo,fon").split(",") if l.strip()
]

# Un seul calcul à la fois : chaque appel dure moins d'une seconde sur le GPU.
_VERROU = threading.Lock()


def prechauffer():
    import mms_asr
    import nllb_translator

    taches = [
        ("MMS fon", lambda: mms_asr._obtenir_modele("fon")),
        ("NLLB", nllb_translator._charger_modele),
    ]
    for lang in LANGUES_VOIX:
        taches.append((f"voix {lang}", lambda lang=lang: kasoro_pipeline._get_mms_model(lang)))

    for nom, charger in taches:
        try:
            charger()
            print(f"[préchauffage] {nom} : OK")
        except Exception as e:
            print(f"[préchauffage] {nom} : échec ({e})")


@asynccontextmanager
async def cycle_de_vie(app):
    prechauffer()
    yield


app = FastAPI(title="Kasoro GPU", lifespan=cycle_de_vie)


def verifier_cle(x_api_key: str = Header(default="")):
    if not secrets.compare_digest(x_api_key.encode(), CLE.encode()):
        raise HTTPException(status_code=401, detail="Clé invalide")


class DemandeTraduction(BaseModel):
    text: str
    source_lang: str
    target_lang: str


class DemandeVoix(BaseModel):
    text: str
    lang: str
    voice: str | None = None  # réservé : voix multiples plus tard, ignoré pour l'instant


@app.get("/health")
def health():
    import torch

    return {"status": "ok", "device": "cuda" if torch.cuda.is_available() else "cpu"}


@app.post("/transcribe", dependencies=[Depends(verifier_cle)])
def transcribe(fichier: UploadFile = File(...), langue: str | None = Form(default=None)):
    suffixe = Path(fichier.filename or "").suffix or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffixe, delete=False) as tmp:
        tmp.write(fichier.file.read())
        chemin = tmp.name
    try:
        with _VERROU:
            resultat = kasoro_pipeline.transcribe_audio(chemin, langue or None)
    finally:
        if os.path.exists(chemin):
            os.remove(chemin)
    return {"text": resultat["text"], "language": resultat["language"]}


@app.post("/translate", dependencies=[Depends(verifier_cle)])
def translate(d: DemandeTraduction):
    try:
        with _VERROU:
            texte = kasoro_pipeline.translate_text(d.text, d.source_lang, d.target_lang)
    except TraductionIndisponible as e:
        raise HTTPException(status_code=422, detail=str(e))
    return {"text": texte}


@app.post("/synthesize", dependencies=[Depends(verifier_cle)])
def synthesize(d: DemandeVoix):
    fd, chemin = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        with _VERROU:
            sortie = kasoro_pipeline.synthesize_speech(d.text, d.lang, chemin)
    except Exception:
        if os.path.exists(chemin):
            os.remove(chemin)
        raise
    return FileResponse(
        sortie, media_type="audio/wav", background=BackgroundTask(os.remove, sortie)
    )