import uuid

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.conversation import Conversation
from app.models.conversation_member import ConversationMember
from app.models.message import Message
from app.models.message_hidden import MessageHidden
from app.models.user import User
from app.schemas.conversation import ConversationCreate, ConversationMemberCreate


async def create_conversation(db: AsyncSession, data: ConversationCreate) -> Conversation:
    conversation = Conversation(name=data.name, is_group=data.is_group)
    db.add(conversation)
    await db.flush()  # obtenir conversation.id avant de créer les membres

    for user_id in data.member_ids:
        user = await db.get(User, user_id)
        if user is None:
            continue
        db.add(
            ConversationMember(
                conversation_id=conversation.id,
                user_id=user_id,
                language=user.preferred_language,
            )
        )

    await db.commit()
    await db.refresh(conversation)
    return conversation


async def get_conversation(db: AsyncSession, conversation_id: uuid.UUID) -> Conversation | None:
    result = await db.execute(
        select(Conversation)
        .where(Conversation.id == conversation_id)
        .options(selectinload(Conversation.members))
    )
    return result.scalar_one_or_none()


async def list_conversations_for_user(db: AsyncSession, user_id: uuid.UUID) -> list[Conversation]:
    conversations = await _conversations_of_user(db, user_id)
    for conversation in conversations:
        result = await db.execute(
            select(Message)
            .where(Message.conversation_id == conversation.id)
            .where(~Message.id.in_(select(MessageHidden.message_id).where(MessageHidden.user_id == user_id)))
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        last = result.scalar_one_or_none()
        if last is not None:
            conversation.last_message_type = getattr(last.message_type, "value", str(last.message_type))
            conversation.last_message_text = last.original_text
            conversation.last_message_at = last.created_at
            conversation.last_message_sender_id = last.sender_id
            member = (await db.execute(select(ConversationMember).where(ConversationMember.conversation_id == conversation.id, ConversationMember.user_id == user_id))).scalar_one_or_none()
            if member is not None:
                counted = await db.execute(select(func.count()).select_from(Message).where(Message.conversation_id == conversation.id, Message.sender_id != user_id, Message.created_at > member.last_read_at, ~Message.id.in_(select(MessageHidden.message_id).where(MessageHidden.user_id == user_id))))
                conversation.unread_count = counted.scalar_one()
    return conversations


async def _conversations_of_user(db: AsyncSession, user_id: uuid.UUID) -> list[Conversation]:
    result = await db.execute(
        select(Conversation)
        .join(ConversationMember)
        .where(ConversationMember.user_id == user_id)
    )
    return list(result.scalars().all())


async def add_member(
    db: AsyncSession, conversation_id: uuid.UUID, data: ConversationMemberCreate
) -> ConversationMember:
    member = ConversationMember(conversation_id=conversation_id, **data.model_dump())
    db.add(member)
    await db.commit()
    await db.refresh(member)
    return member


async def list_members(db: AsyncSession, conversation_id: uuid.UUID) -> list[ConversationMember]:
    result = await db.execute(
        select(ConversationMember).where(ConversationMember.conversation_id == conversation_id)
    )
    return list(result.scalars().all())


async def mark_read(db: AsyncSession, conversation_id: uuid.UUID, user_id: uuid.UUID) -> None:
    result = await db.execute(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conversation_id, ConversationMember.user_id == user_id
        )
    )
    member = result.scalar_one_or_none()
    if member is not None:
        member.last_read_at = func.now()
        await db.commit()


async def remove_member(db: AsyncSession, conversation_id: uuid.UUID, user_id: uuid.UUID) -> None:
    await db.execute(
        delete(ConversationMember).where(
            ConversationMember.conversation_id == conversation_id,
            ConversationMember.user_id == user_id,
        )
    )
    await db.commit()
