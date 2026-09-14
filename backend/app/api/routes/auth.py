from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.core.security import create_access_token
from app.schemas.auth import LoginRequest, Token
from app.services.auth import AuthService, get_auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=Token)
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    user = await auth_service.verify_credentials(db, data.phone_number, data.pin)
    if user is None:
        raise HTTPException(status_code=401, detail="Numéro ou PIN incorrect")
    token = create_access_token(subject=str(user.id))
    return Token(access_token=token)