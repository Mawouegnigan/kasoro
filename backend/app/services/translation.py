"""Interface vers le pipeline de traduction/synthèse vocale existant.

Ce module NE réimplémente PAS le pipeline STT -> MT -> TTS déjà validé
(pipeline/pipeline.py du repo Kasoro, Groq Whisper + Google Translate/MyMemory
+ Meta MMS). Il expose juste le contrat que l'API backend attend, pour que tu
puisses brancher tes fonctions existantes ici sans toucher au reste du code.

TODO (intégration) :
  1. Importer les fonctions réelles depuis pipeline/pipeline.py
     (ex: transcribe_audio, translate_text, synthesize_speech).
  2. Remplacer les corps de méthode ci-dessous par de vrais appels.
  3. Le MMS tourne en local et est lourd à charger : envisager un
     warm cache de modèles par langue au démarrage du service, ou un
     worker séparé (Celery/RQ) si la latence par requête devient un problème.
"""

import asyncio
import uuid
from abc import ABC, abstractmethod
from pathlib import Path
from urllib.parse import urlparse

import httpx

from app.core.config import get_settings


class TranslationService(ABC):
    @abstractmethod
    async def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        """Traduit `text` de `source_lang` vers `target_lang`."""
        raise NotImplementedError

    @abstractmethod
    async def synthesize_audio(self, text: str, lang: str) -> str:
        """Génère l'audio (MMS) pour `text` dans `lang`, retourne une URL/chemin de stockage."""
        raise NotImplementedError

    @abstractmethod
    async def transcribe_audio(self, audio_url: str, language: str | None = None) -> tuple[str, str]:
        """Transcrit un fichier audio (Groq/Whisper). Retourne (texte, langue_détectée)."""
        raise NotImplementedError


class StubTranslationService(TranslationService):
    """Implémentation factice utilisée tant que le vrai pipeline n'est pas branché.

    Permet de faire tourner et tester l'API (routes, cache, modèle de données)
    sans dépendre de Groq/MMS pendant le développement du backend lui-même.
    """

    async def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        return f"[traduction {source_lang}->{target_lang} à brancher] {text}"

    async def synthesize_audio(self, text: str, lang: str) -> str:
        return f"stub://audio/{lang}/not-yet-generated.wav"

    async def transcribe_audio(self, audio_url: str, language: str | None = None) -> tuple[str, str]:
        return "[transcription à brancher]", "fr"


class RealTranslationService(TranslationService):
    """Branche le pipeline réel : pipeline/pipeline.py (Groq Whisper pour le
    STT, Google Translate + fallback MyMemory pour le MT, MMS de Meta en
    local pour le TTS).

    Le dossier pipeline/ est copié/monté dans l'image à côté de app/ (voir
    Dockerfile et docker-compose.yml) et ajouté à PYTHONPATH, donc les
    imports `import pipeline` / `import language_coverage` du code existant
    fonctionnent tels quels, sans aucune modification de pipeline.py.

    Toutes les fonctions du pipeline sont synchrones et bloquantes (appels
    réseau Groq + inférence torch pour MMS) -> exécutées dans un thread
    séparé via asyncio.to_thread pour ne jamais geler la boucle d'événements
    FastAPI pendant qu'une traduction ou une synthèse audio est en cours.
    """

    def __init__(self) -> None:
        self._storage_dir = Path(get_settings().audio_storage_dir)
        self._storage_dir.mkdir(parents=True, exist_ok=True)

    async def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        import pipeline as kasoro_pipeline  # import tardif : évite de charger

        return await asyncio.to_thread(
            kasoro_pipeline.translate_text, text, source_lang, target_lang
        )

    async def synthesize_audio(self, text: str, lang: str) -> str:
        import pipeline as kasoro_pipeline

        filename = f"{uuid.uuid4().hex}.wav"
        output_path = self._storage_dir / filename
        # synthesize_speech peut prendre plusieurs secondes au premier appel
        # pour une langue donnée (téléchargement + chargement du modèle MMS,
        # ensuite mis en cache en mémoire par le pipeline lui-même).
        await asyncio.to_thread(
            kasoro_pipeline.synthesize_speech, text, lang, str(output_path)
        )
        return f"/audio/{filename}"

    async def transcribe_audio(self, audio_url: str, language: str | None = None) -> tuple[str, str]:
        import pipeline as kasoro_pipeline

        local_path = await self._ensure_local_file(audio_url)
        result = await asyncio.to_thread(kasoro_pipeline.transcribe_audio, local_path, language)
        return result["text"], result["language"]

    async def _ensure_local_file(self, audio_url: str) -> str:
        """`transcribe_audio` du pipeline attend un CHEMIN LOCAL, pas une URL.

        original_audio_url peut être :
          - une URL http(s) déjà hébergée ailleurs -> on la télécharge dans
            un fichier temporaire avant de la passer au pipeline ;
          - un chemin déjà servi par ce backend (/audio/xxx.wav) -> on
            résout directement vers le fichier local correspondant ;
          - un chemin déjà local -> utilisé tel quel.
        """
        if audio_url.startswith("http://") or audio_url.startswith("https://"):
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(audio_url)
                response.raise_for_status()
            suffix = Path(urlparse(audio_url).path).suffix or ".m4a"
            tmp_path = self._storage_dir / f"tmp_{uuid.uuid4().hex}{suffix}"
            tmp_path.write_bytes(response.content)
            return str(tmp_path)

        if audio_url.startswith("/audio/"):
            return str(self._storage_dir / audio_url.removeprefix("/audio/"))

        return audio_url


def get_translation_service() -> TranslationService:
    # Point d'extension unique. Bascule contrôlée par USE_REAL_PIPELINE dans
    # .env : false -> stub (dev rapide sans dépendances externes),
    # true -> vrai pipeline Groq/MT/MMS.
    if get_settings().use_real_pipeline:
        return RealTranslationService()
    return StubTranslationService()
