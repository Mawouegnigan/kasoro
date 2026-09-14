"""
Route d'upload audio. Pensée pour être appelée par le mobile AVANT la création
du message : le client upload l'audio, récupère une audio_url, puis l'envoie
dans le payload de création de message (POST /messages). Ça garde la route
messages inchangée — elle continue d'attendre une audio_url, comme aujourd'hui.
"""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File

from app.api.deps import get_current_user
from app.models.user import User
from app.services.storage import (
    AudioStorageError,
    AudioStorageService,
    get_storage_service,
)

router = APIRouter(prefix="/upload", tags=["upload"])


@router.post("/audio", status_code=201)
async def upload_audio(
    file: UploadFile = File(...),
    storage: AudioStorageService = Depends(get_storage_service),
    current_user: User = Depends(get_current_user),
):
    """Upload un fichier audio et retourne son URL exploitable par le pipeline.

    Réponse :
        { "audio_url": "http://.../audio/uploads/<uuid>.mp3" }

    Cette audio_url est ensuite passée telle quelle au payload de création
    de message (POST /messages), qui l'attend déjà en entrée
    (original_audio_url).
    """
    content = await file.read()

    try:
        audio_url = await storage.save(content, file.filename or "audio")
    except AudioStorageError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return {"audio_url": audio_url}