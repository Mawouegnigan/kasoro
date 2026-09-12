# Kasoro

Application de messagerie vocale, pensée d'abord pour les personnes
analphabètes en Afrique, avec traduction automatique entre langues
africaines (texte et audio).

"Kasoro" vient du yoruba — contraction de *jẹ́ ká* ("allons, laissons-nous")
et *sọ̀rọ̀* ("parler") : *"viens, parlons"*.

## Structure du dépôt

- `pipeline/` — prototype de test du pipeline de traduction vocale
  (STT → traduction → TTS). C'est la brique la plus critique du projet,
  à valider avant tout le reste. Voir `pipeline/README.md`.
- `mobile/` — application mobile (Flutter, à venir).
- `backend/` — API et logique serveur (FastAPI, à venir).
- `docs/` — cahier des charges, modèle de données, décisions de conception.

## État actuel du projet

- [x] Idée et positionnement validés (comparaison Lenali / Ayoba)
- [x] Nom choisi : Kasoro
- [x] Modèle de données de la messagerie esquissé (voir `docs/`)
- [ ] Pipeline audio testé avec de vrais échantillons (en cours — `pipeline/`)
- [ ] Backend
- [ ] Application mobile
