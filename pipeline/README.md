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

| Code | Langue | Zone / famille | Statut |
|---|---|---|---|
| `yo` | Yoruba | Afrique de l'Ouest | ✅ pipeline complet exécuté, **validé par un locuteur natif** |
| `fon` | Fon | Bénin | ✅ couverture confirmée (registre soutenu, voir note ci-dessous) |
| `fr` | Français | — | ✅ couverture confirmée |
| `en` | Anglais | — | ✅ couverture confirmée |
| `ha` | Haoussa | Afrique de l'Ouest | ✅ couverture confirmée |
| `sw` | Swahili | Afrique de l'Est | ✅ couverture confirmée |
| `bm` | Bambara | Afrique de l'Ouest | ✅ couverture confirmée |
| `am` | Amharique | Corne de l'Afrique | ✅ couverture confirmée |
| `so` | Somali | Corne de l'Afrique | ✅ couverture confirmée |
| `rw` | Kinyarwanda | Afrique de l'Est | ✅ couverture confirmée |
| `ar` | Arabe | Afrique du Nord | ✅ couverture confirmée |
| `om` | Oromo | Corne de l'Afrique | ✅ couverture confirmée |
| `sn` | Shona | Afrique australe | ✅ couverture confirmée |
| `ny` | Chichewa | Afrique australe | ✅ couverture confirmée |
| `ak` | Akan / Twi | Afrique de l'Ouest | ✅ couverture confirmée |
| `ti` | Tigrinya | Corne de l'Afrique | ✅ couverture confirmée |
| `mg` | Malgache | Afrique de l'Est (Madagascar) | ✅ couverture confirmée |
| `lg` | Luganda | Afrique de l'Est | ✅ couverture confirmée |
| `ki` | Kikuyu | Afrique de l'Est | ✅ couverture confirmée |
| `ee` | Éwé | Afrique de l'Ouest | ✅ couverture confirmée |
| `ff` | Peul / Fulfulde | Afrique de l'Ouest/Sahel | ✅ couverture confirmée |
| `rn` | Kirundi | Afrique de l'Est | ✅ couverture confirmée |

**21 langues confirmées au total**, couvrant les principales zones du
continent (Ouest, Est, Nord, australe, Corne de l'Afrique).

**"Couverture confirmée"** signifie que les deux briques techniques
(traduction + modèle MMS) existent — pas que la qualité a été jugée par un
locuteur natif. **Seul le yoruba a été validé à l'oreille** par un natif
pour l'instant. Le fon fonctionne mais dans un registre soutenu/littéraire
(voir la section dédiée plus bas) — à améliorer avec de vraies
contributions natives (voir `reference_phrases/`).

## Langues avec traduction OK mais voix (MMS) manquante

| Code | Langue | Constat |
|---|---|---|
| `wo` | Wolof | Pas de modèle MMS individuel publié (`facebook/mms-tts-wol` inexistant). |
| `ig` | Igbo | Idem (`facebook/mms-tts-ibo` inexistant, confirmé par erreur "Repository Not Found"). |
| `zu` | Zoulou | Idem (`facebook/mms-tts-zul` inexistant). |
| `af` | Afrikaans | Idem. |
| `xh` | Xhosa | Idem. |
| `ln` | Lingala | Idem. |
| `st` | Sesotho | Idem. |
| `tn` | Tswana | Idem. |

**Ce que ça veut dire** : MMS couvre plus de 1000 langues dans sa recherche
originale, mais Meta n'a pas forcément publié de dépôt Hugging Face
individuel "prêt à l'emploi" pour chacune. Pour ces 8 langues, la
traduction fonctionne très bien — seule la voix manque.

**Pistes pour ces langues, à explorer plus tard** :
- Chercher un modèle TTS communautaire spécialisé (ex : un modèle SpeechT5
  fine-tuné pour le wolof existe sur Hugging Face, à évaluer).
- Revérifier périodiquement — Meta ou la communauté peuvent publier de
  nouveaux checkpoints.
- Accepter ces langues comme non prioritaires pour le MVP, à traiter dans
  une phase ultérieure.

## Adja — non couverte pour l'instant

| Code | Langue | Constat |
|---|---|---|
| `ajg` | Adja | Ni traduction (Google/MyMemory) ni voix (MMS) ne couvrent cette langue sous ce code. |

Contrairement au fon (langue Gbe voisine), l'adja n'a pas encore de
ressources numériques suffisantes dans les outils gratuits qu'on utilise.
Nécessitera une approche différente (ressources communautaires, SIL) —
voir `reference_phrases/ajg.json`, déjà prêt à recevoir des contributions
natives le jour où ça devient une priorité.

## Sur le registre du fon (et bientôt d'autres langues)

Le fon fonctionne techniquement, mais Google Translate/MyMemory produisent
un registre soutenu/littéraire (probablement hérité de corpus religieux
utilisés pour entraîner ces langues peu dotées). Une tentative de
traduction via LLM (`--translator llm`) pour obtenir un ton plus familier
a produit un mélange avec des langues Gbe voisines (gun, éwé) sans
prévenir — donc non fiable en l'état.

La solution retenue : un système de "phrases de référence" validées par de
vrais locuteurs natifs (voir `reference_phrases/README.md`), qui servent
d'exemples pour guider le LLM une fois suffisamment remplies. Tant qu'il
n'y en a pas assez, le pipeline reste sur la traduction classique (`mt`)
par défaut — le choix le plus sûr aujourd'hui.

## Limites connues de ce prototype (normal à ce stade)

- La traduction utilise Google Translate par défaut, qui est parfois
  instable (erreurs serveur), d'où le fallback automatique vers MyMemory.
  Qualité variable selon les langues africaines, et souvent en registre
  soutenu — à comparer un jour avec Lelapa AI ou NLLB-200 si besoin de
  mieux.
- Pas de cache ni de gestion d'erreurs de niveau production : c'est un
  script de test, pas un service prêt à être déployé.
- La vérification de couverture (`check_coverage.py`) confirme que les
  briques techniques existent, pas que leur qualité est suffisante pour un
  vrai lancement public — toujours faire valider par un locuteur natif
  avant d'annoncer une langue comme supportée.