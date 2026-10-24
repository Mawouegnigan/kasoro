import uuid
from datetime import datetime, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.conversation_member import ConversationMember
from app.models.correction import (
    CORRECTION_TRANSCRIPTION,
    STATUS_PENDING,
    STATUS_REJECTED,
    STATUS_VALIDATED,
    Correction,
)
from app.models.message import Message
from app.models.message_translation import MessageTranslation
from app.models.user import User

# Part des corrections validees reservee au jeu de test.
TEST_SET_PERCENT = 15


def _in_test_set(correction_id: uuid.UUID) -> bool:
    # Deterministe : meme identifiant -> meme resultat.
    return int(correction_id.hex, 16) % 100 < TEST_SET_PERCENT


async def create_correction(
    db: AsyncSession,
    message: Message,
    user: User,
    correction_type: str,
    language: str | None,
    corrected_value: str,
) -> Correction:
    translation_id = None
    if correction_type == CORRECTION_TRANSCRIPTION:
        language = message.original_language
        original_value = message.original_text or ""
    else:
        result = await db.execute(
            select(MessageTranslation).where(
                MessageTranslation.message_id == message.id,
                MessageTranslation.language == language,
            )
        )
        translation = result.scalar_one_or_none()
        if translation is not None:
            translation_id = translation.id
            original_value = translation.translated_text
        else:
            original_value = ""

    correction = Correction(
        message_id=message.id,
        translation_id=translation_id,
        correction_type=correction_type,
        language=language,
        original_value=original_value,
        corrected_value=corrected_value.strip(),
        submitted_by=user.id,
    )
    db.add(correction)
    await db.commit()
    await db.refresh(correction)
    return correction


async def get_correction(db: AsyncSession, correction_id: uuid.UUID) -> Correction | None:
    return await db.get(Correction, correction_id)


async def list_pending_for_validator(
    db: AsyncSession, user: User, skip: int = 0, limit: int = 50
) -> list[Correction]:
    """Corrections a valider, dans la langue de l'utilisateur, hors les siennes,
    limitees aux conversations dont il est membre."""
    result = await db.execute(
        select(Correction)
        .join(Message, Message.id == Correction.message_id)
        .join(
            ConversationMember,
            (ConversationMember.conversation_id == Message.conversation_id)
            & (ConversationMember.user_id == user.id),
        )
        .where(Correction.status == STATUS_PENDING)
        .where(Correction.language == user.preferred_language)
        .where(or_(Correction.submitted_by.is_(None), Correction.submitted_by != user.id))
        .order_by(Correction.created_at)
        .offset(skip)
        .limit(limit)
    )
    return list(result.scalars().all())


async def decide_correction(
    db: AsyncSession, correction: Correction, validator: User, approve: bool
) -> Correction:
    correction.status = STATUS_VALIDATED if approve else STATUS_REJECTED
    correction.validated_by = validator.id
    correction.validated_at = datetime.now(timezone.utc)
    correction.is_test_set = approve and _in_test_set(correction.id)
    await db.commit()
    await db.refresh(correction)
    return correction