#!/bin/bash
set -e

echo "==> Running database migrations..."
alembic -c migrations/alembic.ini upgrade head

echo "==> Seeding database..."
python -m pipeline.loaders.db_loader

echo "==> Starting server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
