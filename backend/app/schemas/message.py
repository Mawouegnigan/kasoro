import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.message import MessageType


class MessageCreate(BaseModel):
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    message_type: MessageType = MessageType.text
    original_language: str
    # Pour un message texte : le texte lui-même.
    # Pour un message audio : laisser vide, fournir original_audio_url ;
    # la transcription sera faite par le pipeline STT et remplira original_text.
    original_text: str | None = None
    original_audio_url: str | None = None


class MessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    message_type: MessageType
    original_language: str
    original_text: str | None
    original_audio_url: str | None
    created_at: datetime


class MessageTranslationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    message_id: uuid.UUID
    language: str
    translated_text: str
    translated_audio_url: str | None
    created_at: datetime


class MessageInLanguage(BaseModel):
    """Réponse renvoyée quand un lecteur demande un message dans SA langue.

    `was_cached` indique si la traduction existait déjà (lecture rapide) ou
    vient d'être calculée à l'instant (première lecture dans cette langue).
    """

    message_id: uuid.UUID
    language: str
    text: str
    audio_url: str | None = None
    was_cached: bool
