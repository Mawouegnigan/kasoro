import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ConversationCreate(BaseModel):
    name: str | None = None
    is_group: bool = False
    # Liste des membres initiaux : (user_id, langue de lecture dans cette conversation)
    member_ids: list[uuid.UUID]


class ConversationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str | None
    is_group: bool
    created_at: datetime
    last_message_type: str | None = None
    last_message_text: str | None = None
    last_message_at: datetime | None = None
    last_message_sender_id: uuid.UUID | None = None


class ConversationMemberCreate(BaseModel):
    user_id: uuid.UUID
    language: str


class ConversationMemberRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    conversation_id: uuid.UUID
    user_id: uuid.UUID
    language: str
    joined_at: datetime
