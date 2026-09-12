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
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

from language_coverage import (
    MYMEMORY_LANG_MAP,
    check_language_coverage,
    mms_model_name,
)

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
        mymemory_target = MYMEMORY_LANG_MAP.get(target_lang, target_lang)
        translated = MyMemoryTranslator(source="fr-FR", target=mymemory_target).translate(text)

    # Garde-fou final : si même le fallback renvoie quelque chose de suspect,
    # on arrête ici plutôt que de gaspiller un appel TTS sur du charabia.
    if not translated or any(sig in translated.lower() for sig in ["error 500", "server error", "<html"]):
        raise RuntimeError(f"Traduction invalide après fallback : {translated[:80]!r}")

    elapsed = time.time() - t0
    print(f"    -> Terminé en {elapsed:.1f}s")
    print(f"    -> Texte traduit : {translated}")

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


def run_pipeline(audio_path: str, target_lang: str, output_path: str = None):
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
    args = parser.parse_args()

    if not os.path.exists(args.audio):
        print(f"Erreur : fichier introuvable -> {args.audio}")
        sys.exit(1)

    run_pipeline(args.audio, args.target_lang, args.output)