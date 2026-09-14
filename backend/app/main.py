from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.config import get_settings

settings = get_settings()

app = FastAPI(title=settings.app_name)

app.include_router(api_router, prefix="/api/v1")

# Sert les fichiers audio générés par le TTS (voir app/services/translation.py)
audio_dir = Path(settings.audio_storage_dir)
audio_dir.mkdir(parents=True, exist_ok=True)
app.mount("/audio", StaticFiles(directory=str(audio_dir)), name="audio")


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "app": settings.app_name}
