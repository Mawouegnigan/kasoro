import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db, require_conversation_member
from app.crud import correction as crud_correction
from app.crud import message as crud_message
from app.models.correction import CORRECTION_TRANSLATION, STATUS_PENDING
from app.models.user import User
from app.schemas.correction import CorrectionCreate, CorrectionRead, CorrectionValidate

router = APIRouter(prefix="/corrections", tags=["corrections"])

# Langues ouvertes à la correction pendant la phase d'entraînement.
CORRECTABLE_LANGUAGES = {"fon", "wo"}


@router.post("", response_model=CorrectionRead, status_code=201)
async def create_correction(
    data: CorrectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    message = await crud_message.get_message(db, data.message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    await require_conversation_member(db, message.conversation_id, current_user)

    if data.correction_type == CORRECTION_TRANSLATION and not data.language:
        raise HTTPException(status_code=400, detail="language requis pour une traduction")
    if data.language is not None and len(data.language) > 10:
        raise HTTPException(status_code=400, detail="language invalide")
    if not {message.original_language, data.language} & CORRECTABLE_LANGUAGES:
        raise HTTPException(status_code=422, detail="La correction n'est pas encore ouverte pour cette langue")

    return await crud_correction.create_correction(
        db,
        message,
        current_user,
        data.correction_type,
        data.language,
        data.corrected_value,
    )


@router.get("/pending", response_model=list[CorrectionRead])
async def list_pending(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await crud_correction.list_pending_for_validator(db, current_user, skip, limit)


@router.post("/{correction_id}/validate", response_model=CorrectionRead)
async def validate_correction(
    correction_id: uuid.UUID,
    data: CorrectionValidate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    correction = await crud_correction.get_correction(db, correction_id)
    if correction is None:
        raise HTTPException(status_code=404, detail="Correction introuvable")
    if correction.status != STATUS_PENDING:
        raise HTTPException(status_code=409, detail="Correction deja traitee")
    if correction.submitted_by == current_user.id:
        raise HTTPException(
            status_code=403, detail="Vous ne pouvez pas valider votre propre correction"
        )

    message = await crud_message.get_message(db, correction.message_id)
    if message is None:
        raise HTTPException(status_code=404, detail="Message introuvable")
    await require_conversation_member(db, message.conversation_id, current_user)

    if correction.language != current_user.preferred_language:
        raise HTTPException(
            status_code=403, detail="Votre langue ne correspond pas à cette correction"
        )

    return await crud_correction.decide_correction(db, correction, current_user, data.approve)