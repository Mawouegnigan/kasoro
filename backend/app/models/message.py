import enum
import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, String, Text, Enum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base


class MessageType(str, enum.Enum):
    text = "text"
    audio = "audio"


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    message_type: Mapped[MessageType] = mapped_column(
        Enum(MessageType, name="message_type"), nullable=False, default=MessageType.text
    )
    # Langue d'origine du message (celle de l'auteur au moment de l'envoi)
    original_language: Mapped[str] = mapped_column(String(10), nullable=False)
    # Texte original si type=text, ou transcription STT si type=audio
    original_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    # URL/chemin du fichier audio original envoyé par l'auteur (si type=audio)
    original_audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", back_populates="sent_messages")
    translations = relationship(
        "MessageTranslation", back_populates="message", cascade="all, delete-orphan"
    )
