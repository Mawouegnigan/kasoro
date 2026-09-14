# Kasoro — Backend API

Backend FastAPI implémentant le modèle de données de la messagerie Kasoro
(users, contacts, conversations, conversation_members, messages,
message_translations) avec traduction à la demande + cache.

## Stack

- FastAPI + Uvicorn
- PostgreSQL (async, driver `asyncpg`)
- SQLAlchemy 2.0 (async ORM)
- Alembic (migrations)
- Pydantic v2 (schémas/validation)
- Docker + docker-compose

## Démarrer avec Docker (recommandé, tu as déjà Docker)

```powershell
cd backend
copy .env.example .env
```

Ouvre `.env` et renseigne `GROQ_API_KEY` (celle déjà utilisée par
`pipeline/pipeline.py`). Puis :

```powershell
docker compose up --build
```

**Important** : le build peut prendre du temps la première fois (installation
de `torch`/`transformers`, plusieurs centaines de Mo). C'est normal, ça ne se
reproduit pas aux builds suivants (couches Docker mises en cache).

L'API est disponible sur http://localhost:8000, la doc interactive sur
http://localhost:8000/docs.

Appliquer les migrations (dans un nouveau terminal, conteneur déjà lancé) :

```powershell
docker compose exec api alembic upgrade head
```

### Pipeline réel vs stub

`USE_REAL_PIPELINE` dans `.env` bascule entre :
- `true` (par défaut) : vrai pipeline — Groq (STT), Google Translate +
  fallback MyMemory (MT), MMS de Meta en local (TTS). Nécessite
  `GROQ_API_KEY` et une connexion internet au premier appel TTS par langue
  (téléchargement du modèle MMS, ensuite mis en cache dans un volume Docker
  persistant — pas retéléchargé aux redémarrages suivants).
- `false` : stub, aucune dépendance externe, pour retravailler l'API vite.

Le dossier `pipeline/` (à la racine du repo) est monté directement dans le
conteneur `api` — toute modification de `pipeline/pipeline.py` ou
`pipeline/language_coverage.py` est prise en compte sans reconstruire l'image
(juste un redémarrage du conteneur si le hot-reload d'Uvicorn ne suffit pas).

### Fichiers audio générés

Les audios produits par le TTS sont écrits dans un volume Docker
(`kasoro_audio`) et servis directement par l'API sur `/audio/<fichier>.wav` —
c'est cette URL relative qui est stockée dans `message_translations.translated_audio_url`.

## Démarrer sans Docker (env conda `kasoro`)

Nécessite un PostgreSQL déjà lancé localement (adapter `DATABASE_URL` dans `.env`).

```powershell
conda activate kasoro
pip install -r requirements.txt
copy .env.example .env
alembic upgrade head
uvicorn app.main:app --reload
```

## Pipeline branché (Groq/MT/MMS)

`app/services/translation.py` contient `RealTranslationService`, qui appelle
directement `pipeline/pipeline.py` (aucune réécriture de ta logique — les
fonctions `transcribe_audio`, `translate_text`, `synthesize_speech` sont
utilisées telles quelles, exécutées dans un thread séparé via
`asyncio.to_thread` pour ne pas bloquer le serveur).

Limites connues, à traiter plus tard si la latence par requête devient
gênante en usage réel :
- Le premier appel TTS pour une langue jamais utilisée est plus lent
  (téléchargement + chargement du modèle MMS).
- Pas encore de warm-cache au démarrage ni de file d'attente asynchrone
  (Celery/RQ) — chaque requête attend son traitement complet.

## Logique cœur : traduction à la demande

`app/crud/message.py::get_or_create_translation` est le point central du
produit : un message n'est jamais pré-traduit dans toutes les langues à
l'envoi. La première lecture dans une langue donnée déclenche la traduction +
synthèse vocale, puis le résultat est mis en cache dans `message_translations`
(contrainte `UNIQUE(message_id, language)`). Endpoint associé :

```
GET /api/v1/messages/{message_id}/in/{language}
```

## Structure

```
app/
├── core/       # config (pydantic-settings, lit .env)
├── db/         # base déclarative + session async
├── models/     # 6 modèles SQLAlchemy = 6 tables du schéma
├── schemas/    # contrats Pydantic (entrée/sortie API)
├── crud/       # logique métier / accès DB
├── services/   # interface vers le pipeline de traduction
└── api/routes/ # routeurs FastAPI (users, contacts, conversations, messages)
alembic/        # migrations (une migration initiale déjà écrite à la main)
tests/          # test de fumée (health check)
```

## Ce qui n'est PAS fait ici (à faire ensuite)

- Authentification (aucune, pour l'instant — à ajouter avant tout déploiement réel)
- Branchement réel du pipeline (`StubTranslationService` → vraie implémentation)
- Upload de fichiers audio (les routes prennent une `audio_url` déjà hébergée
  quelque part — stockage S3/Cloudinary/local à décider)
- Rate limiting, pagination avancée, permissions (un membre ne peut lire/écrire
  que dans ses propres conversations, pas encore vérifié côté serveur)
