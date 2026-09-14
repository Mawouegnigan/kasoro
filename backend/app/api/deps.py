import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_access_token
from app.crud import user as crud_user
from app.db.session import get_db  # noqa: F401 (re-exported for convenience)
from app.models.conversation_member import ConversationMember
from app.models.user import User
from app.services.translation import TranslationService, get_translation_service

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_translation_service_dep() -> TranslationService:
    return get_translation_service()


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    user_id_str = decode_access_token(token)
    if user_id_str is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalide")
    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalide")
    user = await crud_user.get_user(db, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utilisateur introuvable")
    return user


async def require_self(user_id: uuid.UUID, current_user: User) -> None:
    """Lève 403 si l'utilisateur connecté n'est pas celui visé par la route."""
    if current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé")


async def require_conversation_member(
    db: AsyncSession, conversation_id: uuid.UUID, current_user: User
) -> None:
    """Lève 403 si l'utilisateur connecté n'est pas membre de la conversation."""
    result = await db.execute(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conversation_id,
            ConversationMember.user_id == current_user.id,
        )
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu n'es pas membre de cette conversation",
        )