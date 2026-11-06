"""Traduction locale avec NLLB-200 (Meta) et garde-fous.

Licence du modèle : CC-BY-NC (usage non commercial) -- à revoir avant
toute exploitation commerciale.
Utilise le GPU s'il existe, sinon le processeur.
"""
import sys
import time

MODEL_NAME = "facebook/nllb-200-distilled-600M"

# Codes Kasoro -> codes NLLB. L'adja n'existe pas dans NLLB.
NLLB_CODES = {
    "fr": "fra_Latn",
    "en": "eng_Latn",
    "yo": "yor_Latn",
    "fon": "fon_Latn",
}


class TraductionIndisponible(Exception):
    """Levée quand la traduction n'est pas fiable : pas de voix générée."""


_tokenizer = None
_model = None
_device = "cpu"


def _charger_modele():
    global _tokenizer, _model, _device
    if _model is None:
        import torch
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

        _device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"    -> Chargement de {MODEL_NAME} (appareil : {_device}) ...")
        _tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
        _model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)
        _model.eval()
        _model.to(_device)
    return _tokenizer, _model


def translate_nllb(text: str, source_lang: str, target_lang: str) -> str:
    import torch

    torch.set_num_threads(4)

    src = NLLB_CODES.get(source_lang)
    tgt = NLLB_CODES.get(target_lang)
    if src is None or tgt is None:
        raise TraductionIndisponible(
            f"Langue non prise en charge par NLLB : {source_lang} -> {target_lang}"
        )

    text = (text or "").strip()
    if not text:
        raise TraductionIndisponible("Texte source vide")

    print(f"[2/3] Traduction NLLB {source_lang} -> {target_lang} ...")
    t0 = time.time()

    tokenizer, model = _charger_modele()
    tokenizer.src_lang = src
    inputs = tokenizer(text, return_tensors="pt")
    inputs = inputs.to(_device)
    nb_tokens = inputs["input_ids"].shape[1]

    with torch.no_grad():
        output = model.generate(
            **inputs,
            forced_bos_token_id=tokenizer.convert_tokens_to_ids(tgt),
            max_new_tokens=min(512, nb_tokens * 3 + 20),
            num_beams=4,
        )
    translated = tokenizer.batch_decode(output, skip_special_tokens=True)[0].strip()

    # --- Garde-fous ---
    if not translated:
        raise TraductionIndisponible("Traduction vide")

    mots_source = text.split()
    if (
        source_lang != target_lang
        and len(mots_source) >= 3
        and translated.lower() == text.lower()
    ):
        raise TraductionIndisponible("Traduction identique à la source")

    if len(translated) > 4 * len(text) + 40:
        raise TraductionIndisponible("Traduction anormalement longue (hors sujet probable)")

    mots = translated.lower().split()
    if len(mots) >= 6 and len(set(mots)) / len(mots) < 0.3:
        raise TraductionIndisponible("Traduction répétitive (hors sujet probable)")

    print(f"    -> Terminé en {time.time() - t0:.1f}s")
    print(f"    -> Texte traduit : {translated}")
    return translated


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print('Usage : python pipeline\\nllb_translator.py <source> <cible> "<texte>"')
        sys.exit(1)
    try:
        translate_nllb(sys.argv[3], sys.argv[1], sys.argv[2])
    except TraductionIndisponible as e:
        print(f"TRADUCTION INDISPONIBLE : {e}")