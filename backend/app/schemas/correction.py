import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

CorrectionType = Literal["transcription", "translation"]


class CorrectionCreate(BaseModel):
    message_id: uuid.UUID
    correction_type: CorrectionType
    # Langue du texte corrige. Obligatoire pour une traduction ; ignoree pour
    # une transcription (on prend la langue d'origine du message).
    language: str | None = None
    corrected_value: str = Field(min_length=1, max_length=5000)


class CorrectionValidate(BaseModel):
    approve: bool


class CorrectionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    message_id: uuid.UUID
    translation_id: uuid.UUID | None
    correction_type: str
    language: str
    original_value: str
    corrected_value: str
    status: str
    submitted_by: uuid.UUID | None
    validated_by: uuid.UUID | None
    validated_at: datetime | None
    is_test_set: bool
    created_at: datetime