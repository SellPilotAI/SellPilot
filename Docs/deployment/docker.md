# Docker

SellPilot runs in Docker for local development and can be deployed as containers in production. This document covers local usage and image layout.

## Local development

From the repo root:

```bash
cp .env.example .env
# Edit backend/.env if you use a local backend env file; or rely on docker-compose env
docker-compose up -d
```

This starts:

- **postgres** on 5432
- **redis** on 6379
- **api** (Django) on 8000
- **frontend** (Next.js) on 3000
- **celery_worker** and **celery_beat** (no exposed ports)

Run migrations and create a superuser inside the API container:

```bash
docker-compose exec api python manage.py migrate
docker-compose exec api python manage.py createsuperuser
```

Or use the scripts:

```bash
./scripts/setup/init_database.sh   # expects DB_* in env or backend/.env
./scripts/setup/create_superuser.sh  # set EMAIL and PASSWORD
```

**Without Docker:**  
Use a local PostgreSQL and Redis, set `DB_*` and `REDIS_URL` in `backend/.env`, then run `python manage.py migrate` and `python manage.py runserver` in the backend, and `npm run dev` in the frontend.

## Image layout

- **Backend:** `backend/Dockerfile` builds a Python image, installs dependencies from `requirements/production.txt`, and runs Gunicorn. For dev, `docker-compose` overrides the command to `runserver`.
- **Frontend:** `frontend/Dockerfile` builds a Node image, runs `npm run build`, and serves with `npm start`. For dev, the command is overridden to `npm run dev`.
- **Nginx:** `infrastructure/docker/nginx/` contains a minimal Nginx config and Dockerfile for use as a reverse proxy in front of the API (Phase 3).

## Production-style run

To run the stack in a production-like way (Gunicorn, `npm start`) with Docker Compose:

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml --profile prod up -d
```

Use this only with proper env and secrets; it is intended as a reference, not a full production setup. Real production is on AWS (or similar) with managed DB, secrets, and scaling (see [aws-setup.md](aws-setup.md) and [ci-cd.md](ci-cd.md)).
