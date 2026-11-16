import uuid
from pathlib import Path
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete as sa_delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    get_db,
    get_current_user,
    get_translation_service_dep,
    require_conversation_member,
    require_self,
)
from app.crud import message as crud_message
from app.core.config import get_settings
from app.models.message import Message
from app.models.message_hidden import MessageHidden
from app.models.message_translation import MessageTranslation
from app.models.user import User
from app.schemas.message import MessageCreate, MessageInLanguage, MessageRead
from app.services.translation import TranslationService, TranslationUnavailableError

router = APIRouter(prefix="/messages", tags=["messages"])


@router.post("", response_model=MessageRead, status_code=201)
async def create_message(
    data: MessageCreate,
    db: AsyncSession = Depends(get_db),
    translation_service: TranslationService = Depends(get_translation_service_dep),
    current_user: User = Depends(get_current_user),
):
    await require_self(data.sender_id, current_user)
    await require_conversation_member(db, data.conversation_id, current_user)

    if data.message_type.value == "text" and not data.original_text:
        raise HTTPException(status_code=400, detail="original_text requis pour un message texte")
    if data.message_type.value == "audio" and not data.original_audio_url:
        raise HTTPException(
            status_code=400, detail="original_audio_url requis pour un message audio"
        )
    try:
        return await crud_message.create_message(db, data, translation_service)
    except crud_message.NoSpeechDetectedError:
        raise HTTPException(
            status_code=422,
            detail="Aucune parole détectée. Réessayez en parlant plus près du micro.",
        )
    except TranslationUnavailableError:
        raise HTTPException(status_code=422, detail="translation_unavailable")


@router.get("/conversation/{conversation_id}", response_model=list[MessageRead])
async def list_messages(
    conversation_id: uuid.UUID,
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_conversation_member(db, conversation_id, current_user)
    return await crud_message.list_messages_for_conversation(db, conversation_id, skip, limit, current_user.id)


def _remove_audio_file(url: str) -> None:
    """Efface un fichier audio du dossier de stockage, sans jamais en sortir."""
    root = Path(get_settings().audio_storage_dir).resolve()
    path = urlparse(url).path
    if "/uploads/" in path:
        rel = "uploads/" + path.split("/uploads/", 1)[1]
    elif "/audio/" in path:
        rel = path.split("/audio/", 1)[1]
    else:
        return
    target = (root / rel).resolve()
    try:
        target.relative_to(root)
    except ValueError:
        return
    if target.is_file():
        target.unlink()


@router.delete("/{message_id}")
async def delete_message(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = await crud_message.get_message(db, message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    if message.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Vous ne pouvez supprimer que vos propres messages")

    result = await db.execute(
        select(MessageTranslation.translated_audio_url).where(
            MessageTranslation.message_id == message.id
        )
    )
    urls = {u for (u,) in result.all() if u}
    if message.original_audio_url:
        urls.add(message.original_audio_url)

    await db.execute(
        sa_delete(Message)
        .where(Message.id == message.id)
        .execution_options(synchronize_session=False)
    )
    await db.commit()

    for url in urls:
        try:
            _remove_audio_file(url)
        except OSError:
            pass
    return {"deleted": True}


@router.post("/{message_id}/hide")
async def hide_message(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = await crud_message.get_message(db, message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    await require_conversation_member(db, message.conversation_id, current_user)
    if message.sender_id == current_user.id:
        raise HTTPException(status_code=400, detail="Utilisez la suppression pour vos propres messages")
    await db.merge(MessageHidden(message_id=message.id, user_id=current_user.id))
    await db.commit()
    return {"hidden": True}


@router.get("/{message_id}/in/{language}", response_model=MessageInLanguage)
async def get_message_in_language(
    message_id: uuid.UUID,
    language: str,
    db: AsyncSession = Depends(get_db),
    translation_service: TranslationService = Depends(get_translation_service_dep),
    current_user: User = Depends(get_current_user),
):
    """Endpoint appelé par le client mobile pour lire un message dans SA langue.

    C'est ici que se joue le différenciateur produit : première lecture dans
    une langue -> traduction + synthèse vocale à la volée puis mise en cache ;
    lectures suivantes -> simple lecture du cache (`was_cached=True`).
    """
    message = await crud_message.get_message(db, message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")

    await require_conversation_member(db, message.conversation_id, current_user)

    try:
        translation, was_cached = await crud_message.get_or_create_translation(
            db, message, language, translation_service
        )
    except TranslationUnavailableError:
        raise HTTPException(status_code=422, detail="translation_unavailable")
    return MessageInLanguage(
        message_id=message_id,
        language=language,
        text=translation.translated_text,
        audio_url=translation.translated_audio_url,
        was_cached=was_cached,
    )