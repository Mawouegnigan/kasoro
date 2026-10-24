import asyncio
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.config import get_settings

settings = get_settings()


def _prechauffer_modeles() -> None:
    """Charge les modèles lourds une seule fois, avant la première requête."""
    from nllb_translator import translate_nllb

    translate_nllb("Bonjour, comment vas-tu ?", "fr", "yo")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # PRELOAD_MODELS=false dans .env désactive le préchargement (dev rapide).
    if settings.use_real_pipeline and os.getenv("PRELOAD_MODELS", "true").lower() == "true":
        print("[démarrage] Préchargement des modèles...")
        try:
            await asyncio.to_thread(_prechauffer_modeles)
            print("[démarrage] Modèles prêts.")
        except Exception as e:
            print(f"[démarrage] Préchargement échoué ({e}) : chargement à la demande.")
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.include_router(api_router, prefix="/api/v1")

# Sert les fichiers audio générés par le TTS (voir app/services/translation.py)
audio_dir = Path(settings.audio_storage_dir)
audio_dir.mkdir(parents=True, exist_ok=True)
app.mount("/audio", StaticFiles(directory=str(audio_dir)), name="audio")


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "app": settings.app_name}