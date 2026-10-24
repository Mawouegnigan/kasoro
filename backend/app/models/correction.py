import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base_class import Base

# Types de correction
CORRECTION_TRANSCRIPTION = "transcription"
CORRECTION_TRANSLATION = "translation"

# Statuts
STATUS_PENDING = "pending"
STATUS_VALIDATED = "validated"
STATUS_REJECTED = "rejected"


class Correction(Base):
    """Correction ou proposition faite par un utilisateur natif.

    - correction_type = "transcription" : le texte transcrit (STT) est corrige.
    - correction_type = "translation" : la traduction est corrigee ou proposee.
      translation_id est vide quand aucune traduction n'existait (ex: adja).

    Une correction reste "pending" jusqu'a confirmation par un second
    utilisateur (validated_by different de submitted_by, regle appliquee
    dans la route). Aucun reentrainement automatique.
    """

    __tablename__ = "corrections"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), nullable=False, index=True
    )
    translation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("message_translations.id", ondelete="SET NULL"), nullable=True
    )
    correction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    language: Mapped[str] = mapped_column(String(10), nullable=False)

    # Copie figee du texte affiche au moment de la correction.
    original_value: Mapped[str] = mapped_column(Text, nullable=False)
    corrected_value: Mapped[str] = mapped_column(Text, nullable=False)

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=STATUS_PENDING, server_default=STATUS_PENDING, index=True
    )
    submitted_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Reserve a la mesure (jeu de test), attribue a la validation.
    is_test_set: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())