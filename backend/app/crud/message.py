import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.message import Message, MessageType
from app.models.message_hidden import MessageHidden
from app.models.message_translation import MessageTranslation
from app.schemas.message import MessageCreate
from app.services.translation import TranslationService
from app.services.translation import TranslationUnavailableError


async def create_message(
    db: AsyncSession, data: MessageCreate, translation_service: TranslationService
) -> Message:
    message = Message(**data.model_dump())

    # Si c'est un message audio et qu'on n'a pas déjà de texte, transcrire (STT).
    if message.message_type == MessageType.audio and not message.original_text:
        text, _ = await translation_service.transcribe_audio(message.original_audio_url, message.original_language)
        if not text.strip():
            raise NoSpeechDetectedError()
        message.original_text = text
        # La langue déclarée par le client (choisie explicitement via un
        # sélecteur, pas saisie en texte libre) est la source fiable — on
        # ne l'écrase JAMAIS avec la détection automatique de Whisper,
        # qui peut se tromper franchement (ex: français détecté comme
        # indonésien sur un audio court/peu clair).

    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def get_message(db: AsyncSession, message_id: uuid.UUID) -> Message | None:
    return await db.get(Message, message_id)


async def list_messages_for_conversation(
    db: AsyncSession, conversation_id: uuid.UUID, skip: int = 0, limit: int = 50,
    user_id: uuid.UUID | None = None,
) -> list[Message]:
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .where(~Message.id.in_(select(MessageHidden.message_id).where(MessageHidden.user_id == user_id)))
        .order_by(Message.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return list(reversed(result.scalars().all()))


# Langues dont la voix n'est pas garantie : le texte est livré sans audio.
AUDIO_OPTIONAL_LANGUAGES = {"wo"}


class NoSpeechDetectedError(Exception):
    """Aucune parole exploitable dans l'audio (silence ou bruit)."""


async def get_or_create_translation(
    db: AsyncSession,
    message: Message,
    target_language: str,
    translation_service: TranslationService,
) -> tuple[MessageTranslation, bool]:
    """Cœur du différenciateur Kasoro.

    - Si le message est déjà dans la langue cible : pas de traduction à faire,
      on renvoie le contenu original tel quel (représenté comme une
      "traduction" identité, pour garder une réponse uniforme côté API).
    - Sinon : on cherche en cache (message_translations). Si absent, on
      traduit et on synthétise l'audio UNE SEULE FOIS, puis on persiste
      grâce à la contrainte UNIQUE(message_id, language), qui sert aussi de
      garde-fou contre les doubles écritures en cas de requêtes concurrentes.

    Retourne (translation, was_cached).
    """
    if target_language == message.original_language:
        # Pas de traduction nécessaire : on matérialise quand même une ligne
        # "identité" pour que tous les lecteurs passent par le même chemin de
        # lecture (simplifie le frontend mobile).
        existing = await _get_cached_translation(db, message.id, target_language)
        if existing:
            return existing, True
        identity = MessageTranslation(
            message_id=message.id,
            language=target_language,
            translated_text=message.original_text or "",
            translated_audio_url=message.original_audio_url,
        )
        identity_message_id = message.id
        db.add(identity)
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            existing = await _get_cached_translation(db, identity_message_id, target_language)
            if existing:
                return existing, True
            raise
        await db.refresh(identity)
        return identity, False

    cached = await _get_cached_translation(db, message.id, target_language)
    if cached:
        return cached, True

    translated_text = await translation_service.translate_text(
        text=message.original_text or "",
        source_lang=message.original_language,
        target_lang=target_language,
    )
    translated_audio_url: str | None = None
    try:
        translated_audio_url = await translation_service.synthesize_audio(
            text=translated_text, lang=target_language
        )
    except TranslationUnavailableError:
        if target_language not in AUDIO_OPTIONAL_LANGUAGES:
            raise

    translation = MessageTranslation(
        message_id=message.id,
        language=target_language,
        translated_text=translated_text,
        translated_audio_url=translated_audio_url,
    )
    translation_message_id = message.id
    db.add(translation)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        cached = await _get_cached_translation(db, translation_message_id, target_language)
        if cached:
            return cached, True
        raise
    await db.refresh(translation)
    return translation, False


async def _get_cached_translation(
    db: AsyncSession, message_id: uuid.UUID, language: str
) -> MessageTranslation | None:
    result = await db.execute(
        select(MessageTranslation).where(
            MessageTranslation.message_id == message_id,
            MessageTranslation.language == language,
        )
    )
    return result.scalar_one_or_none()
