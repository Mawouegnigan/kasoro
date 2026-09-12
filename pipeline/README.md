# Kasoro — Test du pipeline de traduction vocale

Ce dossier valide, en conditions réelles, la brique la plus critique du
projet : la chaîne **audio → transcription → traduction → audio traduit**.
C'est la seule chose qui différencie réellement Kasoro de Lenali ou Ayoba —
donc c'est la première chose à tester, avant tout code d'app.

## Architecture actuelle

| Étape | Techno | Où ça tourne |
|---|---|---|
| STT (transcription) | Groq API, Whisper-large-v3 | Cloud (clé API requise) |
| MT (traduction) | Google Translate + MyMemory (fallback) | Cloud (gratuit, sans clé) |
| TTS (voix) | MMS (Meta), modèle par langue | **Local**, gratuit, sans clé |

## 1. Installer les dépendances

```bash
pip install -r requirements.txt
```

`torch` et `transformers` sont volumineux — l'installation peut prendre
plusieurs minutes.

## 2. Obtenir la clé API Groq (seule clé nécessaire)

- **Groq** (transcription, gratuit en quota d'essai) :
  https://console.groq.com/keys

Copie `.env.example` en `.env` et colle ta clé dedans. La synthèse vocale ne
nécessite plus de clé (MMS tourne en local).

## 3. Préparer un fichier audio de test

Enregistre-toi avec ton téléphone en train de dire une phrase simple en
français (15-20 secondes max). Formats acceptés : `.mp3`, `.wav`, `.ogg`,
`.m4a`, `.flac`, `.webm` (pas `.aac` — Groq le refuse).

## 4. Vérifier la couverture d'une langue AVANT de lancer un test complet

```bash
python check_coverage.py yo fr wo ha sw ig bm am zu so rw
```

Affiche, pour chaque langue, si la traduction et la voix sont réellement
disponibles — évite de découvrir un manque au milieu d'un test.

## 5. Lancer le test complet

```bash
python pipeline.py --audio ton_message.mp3 --target-lang yo
```

Génère `output_yo.wav`. Écoute-le et évalue :

1. **La transcription** correspond-elle fidèlement à ce que tu as dit ?
2. **La traduction** garde-t-elle le bon sens (tons, diacritiques corrects) ?
3. **L'audio généré** est-il compréhensible et naturel pour un vrai locuteur
   natif de la langue cible ? — le juge final, plus fiable que n'importe
   quel test technique.

## Langues validées à ce jour (traduction + voix confirmées par test réel)

| Code | Langue | Testé le |
|---|---|---|
| `yo` | Yoruba | ✅ pipeline complet exécuté, validé par un locuteur natif |
| `fr` | Français | ✅ couverture confirmée |
| `en` | Anglais | ✅ couverture confirmée |
| `ha` | Haoussa | ✅ couverture confirmée |
| `sw` | Swahili | ✅ couverture confirmée |
| `bm` | Bambara | ✅ couverture confirmée |
| `am` | Amharique | ✅ couverture confirmée |
| `so` | Somali | ✅ couverture confirmée |
| `rw` | Kinyarwanda | ✅ couverture confirmée |

**"Couverture confirmée"** signifie que les deux briques techniques
(traduction + modèle MMS) existent — pas que la qualité a été jugée par un
locuteur natif. Seul le yoruba a été validé à l'oreille pour l'instant.

## Langues explorées mais non couvertes par MMS pour l'instant

| Code | Langue | Constat |
|---|---|---|
| `wo` | Wolof | Traduction OK, mais **pas de modèle MMS individuel** publié sur Hugging Face (`facebook/mms-tts-wol` inexistant), malgré une couverture théorique dans la recherche MMS. |
| `ig` | Igbo | Même situation (`facebook/mms-tts-ibo` inexistant, confirmé par test réel — erreur "Repository Not Found"). |
| `zu` | Zoulou | Même situation (`facebook/mms-tts-zul` inexistant). |

**Ce que ça veut dire** : MMS couvre plus de 1000 langues dans sa recherche
originale, mais Meta n'a pas forcément publié de dépôt Hugging Face
individuel "prêt à l'emploi" pour chacune. Le nombre de langues réellement
utilisables avec cette approche est donc plus proche de la liste validée
ci-dessus que du chiffre "1000+" affiché par MMS.

**Pistes pour ces langues, à explorer plus tard** :
- Chercher un modèle TTS communautaire spécialisé (ex : un modèle SpeechT5
  fine-tuné pour le wolof existe sur Hugging Face, à évaluer).
- Revérifier périodiquement — Meta ou la communauté peuvent publier de
  nouveaux checkpoints.
- Accepter ces langues comme non prioritaires pour le MVP, à traiter dans
  une phase ultérieure.

## Fon et Adja (langues cibles du Bénin) — à vérifier

Pas encore testées à ce stade. Prochaine étape : trouver leurs codes ISO
639-3 exacts et lancer `check_coverage.py fon` (ou le code correct) pour
savoir où on en est.

## Limites connues de ce prototype (normal à ce stade)

- La traduction utilise Google Translate par défaut, qui est parfois
  instable (erreurs serveur), d'où le fallback automatique vers MyMemory.
  Qualité variable selon les langues africaines — à comparer un jour avec
  Lelapa AI ou NLLB-200 si besoin de mieux.
- Pas de cache ni de gestion d'erreurs de niveau production : c'est un
  script de test, pas un service prêt à être déployé.
- La vérification de couverture (`check_coverage.py`) confirme que les
  briques techniques existent, pas que leur qualité est suffisante pour un
  vrai lancement public — toujours faire valider par un locuteur natif
  avant d'annoncer une langue comme supportée.