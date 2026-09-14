import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, String, Text, func, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base


class MessageTranslation(Base):
    """Cache des traductions d'un message vers une langue donnée.

    Principe directeur du produit : on ne traduit JAMAIS à l'envoi vers toutes
    les langues des membres. On traduit à la demande, au moment où un premier
    lecteur dans une langue donnée ouvre le message, puis on met en cache ici
    pour tous les lecteurs suivants dans la même langue.

    La contrainte UNIQUE(message_id, language) est le cœur de ce mécanisme :
    elle garantit qu'on ne recalcule/ne stocke jamais deux fois la même paire.
    """

    __tablename__ = "message_translations"
    __table_args__ = (
        UniqueConstraint("message_id", "language", name="uq_translation_message_language"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), nullable=False
    )
    language: Mapped[str] = mapped_column(String(10), nullable=False)

    translated_text: Mapped[str] = mapped_column(Text, nullable=False)
    # Audio régénéré (TTS/MMS) dans la langue cible, une fois calculé
    translated_audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    message = relationship("Message", back_populates="translations")
