"""
Kasoro — Diagnostic de couverture linguistique
=================================================

Vérifie, pour une liste de langues, si chacune est réellement prête
(traduction ET voix) ou seulement partiellement couverte — pour prioriser
l'expansion du projet en connaissance de cause plutôt qu'à l'aveugle.

Usage :
  python check_coverage.py yo fr en wo ha sw ig bm fon adja
  (remplace "fon"/"adja" par leurs vrais codes ISO 639-3 une fois confirmés)

Ou sans argument, pour vérifier un jeu de langues africaines par défaut :
  python check_coverage.py
"""

import sys

from language_coverage import check_language_coverage

DEFAULT_LANGUAGES = ["yo", "fr", "en", "wo", "ha", "sw", "ig", "bm", "fon", "ajg"]


def main():
    languages = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_LANGUAGES

    print(f"Vérification de {len(languages)} langue(s)...\n")
    print(f"{'Langue':<10} {'Traduction':<14} {'Voix (MMS)':<14} {'Statut':<10}")
    print("-" * 50)

    ready_count = 0
    for lang in languages:
        report = check_language_coverage(lang)
        translation = "OK" if report["translation_ok"] else "absente"
        tts = "OK" if report["tts_ok"] else "absente"
        status = "PRÊT" if report["ready"] else "partiel"
        if report["ready"]:
            ready_count += 1
        print(f"{lang:<10} {translation:<14} {tts:<14} {status:<10}")

    print("-" * 50)
    print(f"\n{ready_count}/{len(languages)} langue(s) réellement prêtes "
          f"(traduction + voix confirmées).")
    print(
        "\nRappel : 'PRÊT' signifie que les deux briques techniques existent, "
        "pas que la qualité de traduction/voix est excellente sur cette "
        "langue précise — teste toujours avec un locuteur natif avant de "
        "l'annoncer publiquement."
    )


if __name__ == "__main__":
    main()