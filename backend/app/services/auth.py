"""
Service d'authentification — même logique d'abstraction que TranslationService
et AudioStorageService. PinAuthService aujourd'hui ; une future OtpAuthService
pourra être branchée via config sans toucher aux routes.
"""

from __future__ import annotations

from abc import ABC, abstractmethod

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import verify_secret
from app.crud import user as crud_user
from app.models.user import User

settings = get_settings()


class AuthService(ABC):
    @abstractmethod
    async def verify_credentials(self, db: AsyncSession, phone_number: str, secret: str) -> User | None:
        """Retourne l'utilisateur si les identifiants sont valides, sinon None."""
        raise NotImplementedError


class PinAuthService(AuthService):
    """Vérifie phone_number + PIN contre auth_secret_hash."""

    async def verify_credentials(self, db: AsyncSession, phone_number: str, secret: str) -> User | None:
        user = await crud_user.get_user_by_phone(db, phone_number)
        if user is None:
            return None
        if not verify_secret(secret, user.auth_secret_hash):
            return None
        return user


def get_auth_service() -> AuthService:
    """Point d'entrée unique (dependency injection). Pour brancher OTP plus
    tard : ajouter OtpAuthService ici, changer auth_method dans .env."""
    if settings.auth_method == "pin":
        return PinAuthService()
    raise NotImplementedError(f"Méthode d'auth '{settings.auth_method}' non implémentée.")