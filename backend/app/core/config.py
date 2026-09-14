from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration centrale de l'app, chargée depuis les variables d'env / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Kasoro API"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://kasoro:kasoro@localhost:5432/kasoro"

    # Bascule stub / vrai pipeline (Groq STT + MT + MMS TTS). Mettre à false
    # pour retravailler l'API rapidement sans dépendre de Groq/MMS.
    use_real_pipeline: bool = True

    # Où sont écrits les fichiers audio générés par le TTS, servis ensuite
    # en statique sur /audio/<fichier>.wav
    audio_storage_dir: str = "/code/storage/audio"


@lru_cache
def get_settings() -> Settings:
    return Settings()
