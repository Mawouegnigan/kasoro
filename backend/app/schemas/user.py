import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserBase(BaseModel):
    phone_number: str
    display_name: str | None = None
    preferred_language: str


class UserCreate(UserBase):
    pin: str  # 4-6 chiffres, jamais stocké en clair (voir crud/user.py)


class UserUpdate(BaseModel):
    display_name: str | None = None
    preferred_language: str | None = None
    is_active: bool | None = None


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    is_active: bool
    created_at: datetime