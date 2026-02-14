#!/usr/bin/env bash
# Initialize database for local development. Idempotent.
# Usage: from repo root, ./scripts/setup/init_database.sh
# Requires: PostgreSQL client (psql), env vars or .env in backend/

set -e
cd "$(dirname "$0")/../.."
BACKEND="${BACKEND:-backend}"

if [ ! -d "$BACKEND" ]; then
  echo "Backend dir not found: $BACKEND"
  exit 1
fi

# Load .env if present
if [ -f "$BACKEND/.env" ]; then
  set -a
  source "$BACKEND/.env"
  set +a
fi

DB_NAME="${DB_NAME:-sellpilot}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "Creating database $DB_NAME if not exists..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

echo "Running migrations..."
cd "$BACKEND" && python manage.py migrate --noinput
echo "Done."
