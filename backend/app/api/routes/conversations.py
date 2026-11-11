import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db, require_conversation_member, require_self
from app.crud import conversation as crud_conv
from app.models.user import User
from app.schemas.conversation import (
    ConversationCreate,
    ConversationMemberCreate,
    ConversationMemberRead,
    ConversationRead,
)

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.post("", response_model=ConversationRead, status_code=201)
async def create_conversation(
    data: ConversationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id not in data.member_ids:
        raise HTTPException(
            status_code=403, detail="Vous devez faire partie des membres de la conversation créée"
        )
    if not data.is_group and len(data.member_ids) != 2:
        raise HTTPException(
            status_code=400, detail="Une conversation 1:1 doit avoir exactement 2 membres"
        )
    return await crud_conv.create_conversation(db, data)


@router.get("/{conversation_id}", response_model=ConversationRead)
async def get_conversation(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_conversation_member(db, conversation_id, current_user)
    conversation = await crud_conv.get_conversation(db, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation introuvable")
    return conversation


@router.get("/user/{user_id}", response_model=list[ConversationRead])
async def list_conversations_for_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_self(user_id, current_user)
    return await crud_conv.list_conversations_for_user(db, user_id)


@router.post(
    "/{conversation_id}/members", response_model=ConversationMemberRead, status_code=201
)
async def add_member(
    conversation_id: uuid.UUID,
    data: ConversationMemberCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_conversation_member(db, conversation_id, current_user)
    conversation = await crud_conv.get_conversation(db, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation introuvable")
    return await crud_conv.add_member(db, conversation_id, data)


@router.get("/{conversation_id}/members", response_model=list[ConversationMemberRead])
async def list_members(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_conversation_member(db, conversation_id, current_user)
    return await crud_conv.list_members(db, conversation_id)


@router.post("/{conversation_id}/read", status_code=204)
async def mark_read(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await require_conversation_member(db, conversation_id, current_user)
    await crud_conv.mark_read(db, conversation_id, current_user.id)
