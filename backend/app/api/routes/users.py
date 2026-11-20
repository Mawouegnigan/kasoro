import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db, require_self
from app.api.routes.messages import _remove_audio_file
from app.crud import user as crud_user
from app.models.message import Message
from app.models.message_translation import MessageTranslation
from app.models.user import User
from app.schemas.user import PasswordChange, UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=UserRead, status_code=201)
async def create_user(data: UserCreate, db: AsyncSession = Depends(get_db)):
    """Inscription — publique, pas de token requis (on n'en a pas encore)."""
    existing = await crud_user.get_user_by_phone(db, data.phone_number)
    if existing:
        raise HTTPException(status_code=409, detail="Ce numéro est déjà enregistré")
    return await crud_user.create_user(db, data)


@router.get("", response_model=list[UserRead])
async def list_users(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await crud_user.list_users(db, skip=skip, limit=limit)


@router.get("/{user_id}", response_model=UserRead)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = await crud_user.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user


@router.patch("/{user_id}", response_model=UserRead)
async def update_user(
    user_id: uuid.UUID,
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_self(user_id, current_user)
    user = await crud_user.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return await crud_user.update_user(db, user, data)


@router.delete("/{user_id}", status_code=204)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_self(user_id, current_user)
    user = await crud_user.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Avant de supprimer le compte, on note les fichiers audio de ses messages.
    result = await db.execute(
        select(Message.original_audio_url).where(Message.sender_id == user.id)
    )
    urls = {u for (u,) in result.all() if u}
    result = await db.execute(
        select(MessageTranslation.translated_audio_url)
        .join(Message, Message.id == MessageTranslation.message_id)
        .where(Message.sender_id == user.id)
    )
    urls |= {u for (u,) in result.all() if u}

    await crud_user.delete_user(db, user)

    # Une fois le compte supprimé en base, on efface les fichiers (au mieux).
    for url in urls:
        try:
            _remove_audio_file(url)
        except OSError:
            pass


@router.post("/{user_id}/password", status_code=204)
async def change_password(
    user_id: uuid.UUID,
    data: PasswordChange,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_self(user_id, current_user)
    user = await crud_user.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    if not await crud_user.change_password(db, user, data.old_password, data.new_password):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")