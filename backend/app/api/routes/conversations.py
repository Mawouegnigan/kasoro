import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.crud import conversation as crud_conv
from app.schemas.conversation import (
    ConversationCreate,
    ConversationMemberCreate,
    ConversationMemberRead,
    ConversationRead,
)

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.post("", response_model=ConversationRead, status_code=201)
async def create_conversation(data: ConversationCreate, db: AsyncSession = Depends(get_db)):
    if not data.is_group and len(data.member_ids) != 2:
        raise HTTPException(
            status_code=400, detail="Une conversation 1:1 doit avoir exactement 2 membres"
        )
    return await crud_conv.create_conversation(db, data)


@router.get("/{conversation_id}", response_model=ConversationRead)
async def get_conversation(conversation_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    conversation = await crud_conv.get_conversation(db, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation introuvable")
    return conversation


@router.get("/user/{user_id}", response_model=list[ConversationRead])
async def list_conversations_for_user(user_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    return await crud_conv.list_conversations_for_user(db, user_id)


@router.post(
    "/{conversation_id}/members", response_model=ConversationMemberRead, status_code=201
)
async def add_member(
    conversation_id: uuid.UUID, data: ConversationMemberCreate, db: AsyncSession = Depends(get_db)
):
    conversation = await crud_conv.get_conversation(db, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation introuvable")
    return await crud_conv.add_member(db, conversation_id, data)


@router.get("/{conversation_id}/members", response_model=list[ConversationMemberRead])
async def list_members(conversation_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    return await crud_conv.list_members(db, conversation_id)
