import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db, require_self
from app.crud import contact as crud_contact
from app.models.contact import Contact
from app.models.user import User
from app.schemas.contact import ContactCreate, ContactRead

router = APIRouter(prefix="/contacts", tags=["contacts"])


@router.post("", response_model=ContactRead, status_code=201)
async def create_contact(
    data: ContactCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if data.owner_id == data.contact_user_id:
        raise HTTPException(status_code=400, detail="On ne peut pas s'ajouter soi-même")
    await require_self(data.owner_id, current_user)
    return await crud_contact.create_contact(db, data)


@router.get("/owner/{owner_id}", response_model=list[ContactRead])
async def list_contacts(
    owner_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_self(owner_id, current_user)
    return await crud_contact.list_contacts_for_owner(db, owner_id)


@router.delete("/{contact_id}", status_code=204)
async def delete_contact(
    contact_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    contact = await db.get(Contact, contact_id)
    if contact is None:
        raise HTTPException(status_code=404, detail="Contact introuvable")
    await require_self(contact.owner_id, current_user)
    await crud_contact.delete_contact(db, contact)