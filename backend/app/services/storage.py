"""
Service de stockage audio — même logique d'abstraction que TranslationService
(stub/real). Ici : interface AudioStorageService avec une implémentation
locale aujourd'hui, et un point d'extension propre pour S3/Cloudinary plus tard.

Aucune route ni logique métier ne doit connaître le mécanisme de stockage
réel : elle appelle juste `storage_service.save(...)` et reçoit une URL.
"""

from __future__ import annotations

import os
import uuid
from abc import ABC, abstractmethod
from pathlib import Path

from app.core.config import get_settings

settings = get_settings()


# Formats acceptés en entrée utilisateur (le pipeline convertit ensuite si besoin,
# cf. pipeline/pipeline.py — .aac est rejeté par Groq et doit être converti en .mp3
# AVANT d'être soumis au STT, pas au moment de l'upload/stockage).
ALLOWED_AUDIO_EXTENSIONS = {".mp3", ".wav", ".ogg", ".m4a", ".flac", ".webm", ".aac"}
MAX_AUDIO_SIZE_BYTES = 25 * 1024 * 1024  # 25 Mo, aligné sur la limite Groq Whisper


class AudioStorageError(Exception):
    """Erreur métier de stockage (validation, écriture, etc.)."""


class AudioStorageService(ABC):
    """Interface abstraite. Toute nouvelle implémentation (S3, Cloudinary,
    GCS...) doit respecter ce contrat pour rester interchangeable via config."""

    @abstractmethod
    async def save(self, content: bytes, original_filename: str) -> str:
        """Sauvegarde le contenu binaire et retourne une audio_url exploitable
        directement par le pipeline (ce que le backend attend déjà en entrée
        de `get_or_create_translation` / route messages)."""
        raise NotImplementedError

    @abstractmethod
    async def delete(self, audio_url: str) -> None:
        """Supprime un fichier précédemment stocké, si l'URL lui appartient."""
        raise NotImplementedError


class LocalAudioStorageService(AudioStorageService):
    """Stockage sur disque, dans `audio_storage_dir` — le même répertoire
    déjà utilisé pour l'audio généré par le TTS (MMS), donc aucun nouveau
    volume Docker à déclarer.

    Convention de nommage : sous-dossier "uploads/" pour distinguer
    visuellement des fichiers générés par le pipeline TTS (qui vivent à la
    racine de audio_storage_dir), tout en restant dans le même répertoire
    monté et servi en statique.
    """

    def __init__(self, base_path: str | None = None, base_url: str | None = None):
        self.base_path = Path(base_path or settings.audio_storage_dir) / "uploads"
        self.base_url = (base_url or settings.audio_base_url).rstrip("/")
        self.base_path.mkdir(parents=True, exist_ok=True)

    def _validate(self, content: bytes, original_filename: str) -> str:
        ext = Path(original_filename).suffix.lower()
        if ext not in ALLOWED_AUDIO_EXTENSIONS:
            raise AudioStorageError(
                f"Format non supporté : '{ext}'. Formats acceptés : "
                f"{', '.join(sorted(ALLOWED_AUDIO_EXTENSIONS))}"
            )
        if len(content) == 0:
            raise AudioStorageError("Fichier audio vide.")
        if len(content) > MAX_AUDIO_SIZE_BYTES:
            raise AudioStorageError(
                f"Fichier trop volumineux ({len(content) / 1_000_000:.1f} Mo, "
                f"max {MAX_AUDIO_SIZE_BYTES / 1_000_000:.0f} Mo)."
            )
        return ext

    async def save(self, content: bytes, original_filename: str) -> str:
        ext = self._validate(content, original_filename)
        filename = f"{uuid.uuid4().hex}{ext}"
        filepath = self.base_path / filename

        # Écriture synchrone volontairement gardée simple (I/O locale rapide) ;
        # si ça devient un point chaud, passer à aiofiles ou asyncio.to_thread
        # comme le reste des appels bloquants du pipeline.
        filepath.write_bytes(content)

        return f"{self.base_url}/uploads/{filename}"

    async def delete(self, audio_url: str) -> None:
        filename = audio_url.rstrip("/").split("/")[-1]
        filepath = self.base_path / filename
        # Vérification anti-path-traversal : le fichier résolu doit rester
        # dans base_path, même si un nom de fichier malicieux est fourni.
        try:
            filepath.resolve().relative_to(self.base_path.resolve())
        except ValueError:
            raise AudioStorageError("Chemin de fichier invalide.")
        if filepath.exists():
            os.remove(filepath)


def get_storage_service() -> AudioStorageService:
    """Point d'entrée unique utilisé par les routes (dependency injection FastAPI).
    Pour brancher S3/Cloudinary plus tard : ajouter S3AudioStorageService ici,
    et changer audio_storage_backend dans .env — aucune route à modifier."""
    backend = settings.audio_storage_backend
    if backend == "local":
        return LocalAudioStorageService()
    raise NotImplementedError(
        f"Backend de stockage '{backend}' non implémenté. "
        f"Actuellement disponible : 'local'."
    )