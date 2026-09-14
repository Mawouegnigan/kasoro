import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, String, func, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base


class ConversationMember(Base):
    """Table pivot conversations <-> users.

    Le champ `language` capture la langue de LECTURE de ce membre dans CETTE
    conversation (peut différer de son preferred_language global si besoin).
    C'est cette colonne, agrégée sur tous les membres d'une conversation, qui
    détermine vers quelles langues une traduction est un jour nécessaire.
    """

    __tablename__ = "conversation_members"
    __table_args__ = (
        UniqueConstraint("conversation_id", "user_id", name="uq_member_conversation_user"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    language: Mapped[str] = mapped_column(String(10), nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation = relationship("Conversation", back_populates="members")
    user = relationship("User", back_populates="memberships")
