import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ContactCreate(BaseModel):
    owner_id: uuid.UUID
    contact_user_id: uuid.UUID
    alias: str | None = None


class ContactRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    owner_id: uuid.UUID
    contact_user_id: uuid.UUID
    alias: str | None
    created_at: datetime
