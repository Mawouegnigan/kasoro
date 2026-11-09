import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserBase(BaseModel):
    phone_number: str
    display_name: str | None = None
    preferred_language: str


class UserCreate(UserBase):
    pin: str = Field(min_length=8, max_length=72)  # mot de passe : 8 caractères minimum (jamais stocké en clair, voir crud/user.py)


class UserUpdate(BaseModel):
    display_name: str | None = None
    preferred_language: str | None = None
    is_active: bool | None = None


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    is_active: bool
    created_at: datetime


class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(min_length=8, max_length=72)
