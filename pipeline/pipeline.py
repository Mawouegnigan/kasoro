"""
Kasoro — Pipeline de traduction vocale (prototype de test)
============================================================

Objectif : valider la brique la plus critique du projet avant de construire
quoi que ce soit d'autre autour — est-ce que la chaîne
audio original -> transcription -> traduction -> audio traduit
produit un résultat compréhensible et fidèle dans une langue africaine cible ?

Étapes :
  1. STT  (Speech-to-Text) : Groq API, modèle Whisper-large-v3
  2. MT   (Traduction)     : Google Translate via deep-translator (fallback simple,
                              à remplacer plus tard par Lelapa AI / NLLB si besoin
                              d'une meilleure couverture des langues africaines)
  3. TTS  (Text-to-Speech) : MMS (Meta), modèle spécifique par langue, exécuté
                              en local — pas d'API, pas de clé, gratuit

Usage :
  python pipeline.py --audio message.ogg --target-lang yo

Prérequis :
  pip install -r requirements.txt
  Variables d'environnement (voir .env.example) :
    GROQ_API_KEY=...

Note : le premier lancement pour une langue donnée télécharge le modèle
MMS-TTS correspondant depuis Hugging Face (~100 Mo) — il faut une connexion
internet la première fois, mais plus ensuite (modèle mis en cache localement).
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

from language_coverage import (
    check_language_coverage,
    mms_model_name,
    resolve_mymemory_code,
)

REFERENCE_PHRASES_DIR = Path(__file__).parent / "reference_phrases"


def load_validated_examples(target_lang: str, min_examples: int = 3) -> list:
    """Charge les phrases de référence validées par un locuteur natif pour
    cette langue, si le fichier existe et contient assez d'exemples validés.

    Retourne une liste vide si rien n'est encore validé (comportement par
    défaut tant que personne n'a rempli reference_phrases/<code>.json).
    """
    path = REFERENCE_PHRASES_DIR / f"{target_lang}.json"
    if not path.exists():
        return []

    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return []

    validated = [
        p for p in data.get("phrases", [])
        if p.get("validated_by_native") and p.get("translation")
    ]

    if len(validated) < min_examples:
        return []

    return validated

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# Cache en mémoire des modèles MMS déjà chargés, pour ne pas les recharger
# à chaque appel dans la même exécution.
_MMS_MODELS = {}


def transcribe_audio(audio_path: str) -> dict:
    """Étape 1 : Speech-to-Text via Groq (Whisper-large-v3).

    Retourne un dict avec le texte transcrit et la langue détectée.
    """
    from groq import Groq

    if not GROQ_API_KEY:
        raise EnvironmentError("GROQ_API_KEY manquant dans l'environnement (.env)")

    client = Groq(api_key=GROQ_API_KEY)

    print(f"[1/3] Transcription de {audio_path} ...")
    t0 = time.time()

    with open(audio_path, "rb") as f:
        result = client.audio.transcriptions.create(
            file=(Path(audio_path).name, f.read()),
            model="whisper-large-v3",
            response_format="verbose_json",  # renvoie aussi la langue détectée
        )

    elapsed = time.time() - t0
    print(f"    -> Terminé en {elapsed:.1f}s")
    print(f"    -> Langue détectée : {result.language}")
    print(f"    -> Texte : {result.text}")

    return {"text": result.text, "language": result.language}


def translate_text(text: str, source_lang: str, target_lang: str) -> str:
    """Étape 2 : Traduction du texte transcrit vers la langue cible.

    Utilise Google Translate (via deep-translator) comme premier jalon.
    À remplacer/comparer plus tard avec Lelapa AI ou NLLB-200 pour évaluer
    la qualité spécifique sur les langues africaines les moins couvertes.
    """
    from deep_translator import GoogleTranslator, MyMemoryTranslator

    print(f"[2/3] Traduction {source_lang} -> {target_lang} ...")
    t0 = time.time()

    try:
        translated = GoogleTranslator(source="auto", target=target_lang).translate(text)
        # Google renvoie parfois une page d'erreur HTML au lieu de lever une
        # exception -> on détecte ce cas sur des signaux stables (peu importe
        # le type d'apostrophe utilisé dans le message d'erreur).
        error_signals = ["error 500", "server error", "<html"]
        looks_broken = (
            not translated
            or len(translated) > 500  # une vraie traduction ne fait pas 500+ caractères pour une phrase courte
            or any(sig in translated.lower() for sig in error_signals)
        )
        if looks_broken:
            raise RuntimeError(f"Réponse suspecte de Google Translate : {translated[:80]!r}")
    except Exception as e:
        print(f"    -> Google Translate a échoué ({e}), bascule sur MyMemory...")
        mymemory_target = resolve_mymemory_code(target_lang) or target_lang
        translated = MyMemoryTranslator(source="fr-FR", target=mymemory_target).translate(text)

    # Garde-fou final : si même le fallback renvoie quelque chose de suspect,
    # on arrête ici plutôt que de gaspiller un appel TTS sur du charabia.
    if not translated or any(sig in translated.lower() for sig in ["error 500", "server error", "<html"]):
        raise RuntimeError(f"Traduction invalide après fallback : {translated[:80]!r}")

    elapsed = time.time() - t0
    print(f"    -> Terminé en {elapsed:.1f}s")
    print(f"    -> Texte traduit : {translated}")

    return translated


# Noms des langues en français, pour construire des prompts clairs.
LANG_NAMES_FR = {
    "yo": "yoruba",
    "fr": "français",
    "en": "anglais",
    "wo": "wolof",
    "ha": "haoussa",
    "sw": "swahili",
    "ig": "igbo",
    "bm": "bambara",
    "fon": "fon",
}


def translate_text_llm(text: str, target_lang: str, model: str = "openai/gpt-oss-120b") -> str:
    """Traduction alternative via un LLM (Groq), avec consigne explicite de
    registre familier/parlé.

    Contrairement à Google Translate/MyMemory (qui reproduisent le registre
    dominant de leurs données d'entraînement — souvent des textes religieux
    pour les langues africaines peu dotées, d'où un ton "soutenu"), on
    demande ici explicitement une traduction courante, de tous les jours.

    ATTENTION : pour une langue aussi peu dotée que le fon, un LLM peut
    "halluciner" du vocabulaire de façon fluide mais incorrecte. À valider
    impérativement par un locuteur natif avant de faire confiance au résultat
    — plus encore que pour la traduction classique.
    """
    from groq import Groq

    if not GROQ_API_KEY:
        raise EnvironmentError("GROQ_API_KEY manquant dans l'environnement (.env)")

    client = Groq(api_key=GROQ_API_KEY)
    target_name = LANG_NAMES_FR.get(target_lang, target_lang)

    print(f"[2/3] Traduction (LLM, registre familier) vers le {target_name} ...")
    t0 = time.time()

    examples = load_validated_examples(target_lang)

    if examples:
        print(f"    -> {len(examples)} exemple(s) validé(s) par un natif utilisés comme repère.")
        examples_block = "\n".join(
            f"Français : {ex['fr']}\n{target_name.capitalize()} : {ex['translation']}"
            for ex in examples
        )
        prompt = (
            f"Voici des exemples authentiques de traduction en {target_name} "
            f"parlé courant, validés par un locuteur natif :\n\n{examples_block}\n\n"
            f"En suivant EXACTEMENT ce même style et cette même langue (pas une "
            f"langue voisine), traduis la phrase suivante :\n\n"
            f"Français : {text}\n{target_name.capitalize()} :"
        )
    else:
        print(
            "    -> Aucun exemple validé pour cette langue (voir "
            "reference_phrases/) : traduction générique, risque de mélange "
            "avec une langue voisine, à valider impérativement."
        )
        prompt = (
            f"Tu es un locuteur natif du {target_name}, qui parle au quotidien "
            f"avec sa famille et ses amis. Traduis la phrase suivante en {target_name} "
            f"PARLÉ COURANT — pas en registre soutenu, littéraire ou religieux. "
            f"Réponds uniquement avec la traduction, sans aucun commentaire ni "
            f"explication.\n\nPhrase à traduire : {text}"
        )

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
        )
    except Exception as e:
        # Le catalogue de modèles Groq change régulièrement (dépréciations
        # fréquentes) -> plutôt que de deviner un autre nom, on affiche la
        # vraie liste des modèles accessibles sur CE compte.
        try:
            available = [m.id for m in client.models.list().data]
        except Exception:
            available = ["(impossible de récupérer la liste, vérifie ta connexion)"]

        raise RuntimeError(
            f"Le modèle '{model}' n'est pas accessible sur ton compte Groq ({e}).\n"
            f"Modèles actuellement disponibles : {available}\n"
            f"Relance avec, par exemple : --llm-model {available[0] if available else '<nom>'}"
        ) from e

    translated = response.choices[0].message.content.strip()

    elapsed = time.time() - t0
    print(f"    -> Terminé en {elapsed:.1f}s")
    print(f"    -> Texte traduit : {translated}")
    if examples:
        print(
            "    -> Traduction guidée par des exemples validés — fiabilité "
            "nettement meilleure, mais fais quand même confirmer le résultat "
            "final par ton contact natif."
        )
    else:
        print(
            "    -> /!\\ Traduction expérimentale (LLM, sans exemple validé) : "
            "fais-la valider par un locuteur natif, risque de mélange avec "
            "une langue voisine."
        )

    return translated


def _get_mms_model(target_lang: str):
    """Charge (et met en cache en mémoire) le modèle MMS-TTS pour une langue.

    Résolution dynamique : n'importe quel code langue est accepté, tant
    qu'un modèle MMS existe réellement sur Hugging Face pour ce code
    (vérifié avant téléchargement, pas après un plantage).

    Au premier appel pour une langue donnée, le modèle est téléchargé
    depuis Hugging Face (quelques dizaines de Mo) et mis en cache local
    sur le disque (~/.cache/huggingface) — les appels suivants sont
    instantanés, même hors ligne.
    """
    from transformers import VitsModel, AutoTokenizer

    if target_lang not in _MMS_MODELS:
        model_name = mms_model_name(target_lang)

        print(f"    -> Vérification de la disponibilité de {model_name} ...")
        model = VitsModel.from_pretrained(model_name)  # échoue proprement si le dépôt n'existe pas
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        _MMS_MODELS[target_lang] = (model, tokenizer)

    return _MMS_MODELS[target_lang]


def synthesize_speech(text: str, target_lang: str, output_path: str) -> str:
    """Étape 3 : Text-to-Speech via MMS (Meta), exécuté en local.

    Contrairement à ElevenLabs, ce n'est pas un modèle multilingue générique
    mais un modèle entraîné spécifiquement pour chaque langue — donc, en
    théorie, une bien meilleure gestion des tons pour des langues comme
    le yoruba.
    """
    import torch
    import scipy.io.wavfile

    # MMS génère du .wav — on adapte l'extension si le nom de fichier
    # demandé était pensé pour du .mp3.
    if not output_path.lower().endswith(".wav"):
        output_path = output_path.rsplit(".", 1)[0] + ".wav"

    print(f"[3/3] Génération audio (MMS-TTS, langue: {target_lang}) ...")
    t0 = time.time()

    model, tokenizer = _get_mms_model(target_lang)

    inputs = tokenizer(text, return_tensors="pt")
    with torch.no_grad():
        output = model(**inputs).waveform

    waveform = output[0].cpu().numpy()
    scipy.io.wavfile.write(output_path, rate=model.config.sampling_rate, data=waveform)

    elapsed = time.time() - t0
    print(f"    -> Terminé en {elapsed:.1f}s")
    print(f"    -> Fichier généré : {output_path}")

    return output_path


def run_pipeline(audio_path: str, target_lang: str, output_path: str = None, translator: str = "mt", llm_model: str = "openai/gpt-oss-120b"):
    if output_path is None:
        output_path = f"output_{target_lang}.wav"

    print("=" * 60)
    print("KASORO — Test du pipeline de traduction vocale")
    print("=" * 60)

    coverage = check_language_coverage(target_lang)
    print(f"Vérification de la couverture pour '{target_lang}' :")
    print(f"  - Traduction (MT)  : {'OK' if coverage['translation_ok'] else 'NON COUVERTE'}")
    print(f"  - Voix (MMS-TTS)   : {'OK' if coverage['tts_ok'] else 'NON COUVERTE'} ({coverage['mms_model']})")
    if not coverage["ready"]:
        print(
            "  /!\\ Couverture partielle : le test peut échouer ou produire "
            "un résultat de mauvaise qualité. On continue quand même, à "
            "titre exploratoire."
        )
    print()

    stt_result = transcribe_audio(audio_path)
    if translator == "llm":
        translated_text = translate_text_llm(stt_result["text"], target_lang, model=llm_model)
    else:
        translated_text = translate_text(
            stt_result["text"], stt_result["language"], target_lang
        )
    synthesize_speech(translated_text, target_lang, output_path)

    print("=" * 60)
    print("Résumé")
    print("=" * 60)
    print(f"Texte original ({stt_result['language']}) : {stt_result['text']}")
    print(f"Texte traduit  ({target_lang})            : {translated_text}")
    print(f"Audio final                               : {output_path}")
    print()
    print("=> Écoute le fichier généré et évalue :")
    print("   1. Le texte transcrit correspond-il bien à ce que tu as dit ?")
    print("   2. La traduction est-elle fidèle au sens ?")
    print("   3. La voix générée est-elle compréhensible et naturelle ?")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Teste le pipeline STT -> Traduction -> TTS de Kasoro"
    )
    parser.add_argument("--audio", required=True, help="Chemin du fichier audio à traduire")
    parser.add_argument("--target-lang", required=True, help="Code langue cible (ex: yo, fr, en)")
    parser.add_argument("--output", help="Chemin du fichier audio de sortie")
    parser.add_argument(
        "--translator",
        choices=["mt", "llm"],
        default="mt",
        help="'mt' = Google Translate/MyMemory (par défaut). "
             "'llm' = Groq (registre familier explicite, expérimental).",
    )
    parser.add_argument(
        "--llm-model",
        default="openai/gpt-oss-120b",
        help="Modèle Groq à utiliser avec --translator llm (le catalogue "
             "Groq change régulièrement, ajuste si besoin).",
    )
    args = parser.parse_args()

    if not os.path.exists(args.audio):
        print(f"Erreur : fichier introuvable -> {args.audio}")
        sys.exit(1)

    run_pipeline(args.audio, args.target_lang, args.output, translator=args.translator, llm_model=args.llm_model)