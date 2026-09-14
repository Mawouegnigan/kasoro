# IMPORTANT : ce Dockerfile est conçu pour être construit avec le contexte
# à la RACINE du repo (kasoro/), pas depuis backend/ tout seul — c'est
# docker-compose.yml qui s'en charge (context: .., dockerfile: backend/Dockerfile).
# Nécessaire pour pouvoir copier pipeline/ à côté de app/.

FROM python:3.12-slim

WORKDIR /code

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY backend/alembic ./alembic
COPY backend/alembic.ini .

# Le pipeline STT/MT/TTS existant, copié tel quel (pipeline.py fait
# `from language_coverage import ...` en import "plat" : il faut donc que ce
# dossier soit sur PYTHONPATH, pas juste présent sur le disque).
COPY pipeline ./pipeline
ENV PYTHONPATH=/code/pipeline:${PYTHONPATH}

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
