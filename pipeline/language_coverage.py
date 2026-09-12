"""
Kasoro — Résolution et vérification de la couverture linguistique
====================================================================

Plutôt qu'une liste figée de langues "supportées", ce module vérifie
dynamiquement, pour n'importe quel code langue, si :

  1. La traduction (Google Translate / MyMemory) le couvre.
  2. La synthèse vocale (MMS de Meta) le couvre.

Objectif : dire honnêtement "cette langue est prête" ou "cette langue n'est
que partiellement couverte" AVANT de lancer un test, plutôt que de laisser
échouer le pipeline au milieu avec une erreur cryptique.

Rappel important : ajouter une langue au pipeline ne coûte qu'une ligne de
code côté voix (MMS couvre 1000+ langues), mais la qualité réelle dépend
presque toujours de la traduction (MT) — le vrai goulot d'étranglement.
Ce module sert à distinguer les deux plutôt que d'annoncer une couverture
qui n'existerait que sur le papier.
"""

# Cas où le code ISO 639-1 à 2 lettres ne correspond pas exactement au code
# ISO 639-3 utilisé par MMS (ex : macrolangue vs langue individuelle).
# À enrichir au fil des découvertes.
MMS_CODE_OVERRIDES = {
    "sw": "swh",  # MMS utilise le swahili "individuel" (swh), pas la macrolangue (swa)
}

# MyMemory attend un format "langue-PAYS" plutôt qu'un simple code langue.
# À enrichir au fil de l'ajout de nouvelles langues cibles.
MYMEMORY_LANG_MAP = {
    "yo": "yo-NG",   # yoruba (Nigeria)
    "fr": "fr-FR",
    "en": "en-GB",
    "wo": "wo-SN",   # wolof (Sénégal)
    "ha": "ha-NE",   # haoussa
    "sw": "sw-KE",   # swahili
    "ig": "ig-NG",   # igbo
    "bm": "bm-ML",   # bambara
}

# Caches en mémoire (par exécution) pour éviter de refaire les mêmes
# vérifications réseau plusieurs fois.
_mms_availability_cache: dict[str, bool] = {}
_google_langs_cache: dict | None = None


def resolve_mms_code(lang_code: str) -> str:
    """Convertit un code langue (ex: 'yo', 'fr') en code ISO 639-3 utilisé par MMS.

    Ordre de résolution :
      1. Table d'exceptions connues (MMS_CODE_OVERRIDES).
      2. Conversion automatique via pycountry (ISO 639-1 -> ISO 639-3).
      3. Si le code fourni fait déjà 3 lettres, on suppose qu'il s'agit
         déjà d'un code ISO 639-3 valide.
    """
    if lang_code in MMS_CODE_OVERRIDES:
        return MMS_CODE_OVERRIDES[lang_code]

    if len(lang_code) == 2:
        try:
            import pycountry

            lang = pycountry.languages.get(alpha_2=lang_code)
            if lang is not None and hasattr(lang, "alpha_3"):
                return lang.alpha_3
        except Exception:
            pass

    if len(lang_code) == 3:
        return lang_code

    raise ValueError(
        f"Impossible de résoudre un code ISO 639-3 pour '{lang_code}'. "
        f"Essaie de fournir directement le code à 3 lettres utilisé par MMS "
        f"(voir https://dl.fbaipublicfiles.com/mms/misc/language_coverage_mms.html)."
    )


def mms_model_name(lang_code: str) -> str:
    """Retourne le nom du dépôt Hugging Face du modèle MMS-TTS pour cette langue."""
    return f"facebook/mms-tts-{resolve_mms_code(lang_code)}"


def check_mms_tts_support(lang_code: str) -> bool:
    """Vérifie si un modèle MMS-TTS existe réellement sur Hugging Face pour cette langue.

    Résultat mis en cache pour la durée de l'exécution.
    """
    try:
        model_name = mms_model_name(lang_code)
    except ValueError:
        return False

    if model_name in _mms_availability_cache:
        return _mms_availability_cache[model_name]

    try:
        from huggingface_hub import model_info
        from huggingface_hub.errors import RepositoryNotFoundError

        model_info(model_name)
        result = True
    except RepositoryNotFoundError:
        result = False
    except Exception:
        # Hors ligne ou erreur réseau : on ne peut pas confirmer, mais on ne
        # veut pas non plus bloquer -> on suppose "peut-être disponible",
        # le vrai chargement plus tard tranchera.
        result = True

    _mms_availability_cache[model_name] = result
    return result


def check_translation_support(lang_code: str) -> bool:
    """Vérifie si Google Translate ou MyMemory couvre cette langue cible."""
    global _google_langs_cache

    if lang_code in MYMEMORY_LANG_MAP:
        return True

    try:
        if _google_langs_cache is None:
            from deep_translator import GoogleTranslator

            _google_langs_cache = GoogleTranslator().get_supported_languages(as_dict=True)
        return lang_code in _google_langs_cache.values() or lang_code in _google_langs_cache
    except Exception:
        return False


def check_language_coverage(lang_code: str) -> dict:
    """Rapport complet de couverture pour une langue cible donnée."""
    translation_ok = check_translation_support(lang_code)
    tts_ok = check_mms_tts_support(lang_code)

    try:
        model_name = mms_model_name(lang_code)
    except ValueError:
        model_name = None

    return {
        "lang_code": lang_code,
        "translation_ok": translation_ok,
        "tts_ok": tts_ok,
        "mms_model": model_name,
        "ready": translation_ok and tts_ok,
    }
