from app.db.session import get_db  # noqa: F401 (re-exported for convenience)
from app.services.translation import TranslationService, get_translation_service


def get_translation_service_dep() -> TranslationService:
    return get_translation_service()
