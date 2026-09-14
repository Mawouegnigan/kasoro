from fastapi import APIRouter

from app.api.routes import contacts, conversations, messages, users

api_router = APIRouter()
api_router.include_router(users.router)
api_router.include_router(contacts.router)
api_router.include_router(conversations.router)
api_router.include_router(messages.router)
