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

    # Mode du pipeline reel : local (dans le conteneur) ou remote (pod GPU)
    pipeline_mode: str = "local"
    gpu_service_url: str = ""
    gpu_api_key: str = ""

    # Où sont écrits les fichiers audio générés par le TTS, servis ensuite
    # en statique sur /audio/<fichier>.wav
    audio_storage_dir: str = "/code/storage/audio"

    # Backend de stockage pour l'audio uploadé par l'utilisateur.
    # "local" pour l'instant ; permet de brancher S3/Cloudinary plus tard
    # sans changer les routes (voir app/services/storage.py).
    audio_storage_backend: str = "local"

    # Base URL utilisée pour construire les audio_url retournées par l'API
    # (upload utilisateur et audio généré par le TTS).
    audio_base_url: str = "http://localhost:8000/audio"

    # --- Authentification ---
    # "pin" pour l'instant ; "otp" plus tard sans changer les routes
    # (voir app/services/auth.py)
    auth_method: str = "pin"
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 7 jours


@lru_cache
def get_settings() -> Settings:
    return Settings()