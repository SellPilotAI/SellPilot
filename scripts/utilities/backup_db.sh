#!/usr/bin/env bash
# Backup PostgreSQL database. Usage: ./scripts/utilities/backup_db.sh [output_path]
# Requires: pg_dump, env vars DB_* or .env in backend/

set -e
cd "$(dirname "$0")/../.."
BACKEND="${BACKEND:-backend}"

if [ -f "$BACKEND/.env" ]; then
  set -a
  source "$BACKEND/.env"
  set +a
fi

DB_NAME="${DB_NAME:-sellpilot}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
OUT="${1:-backup_${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql}"

echo "Backing up $DB_NAME to $OUT..."
PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -F p "$DB_NAME" > "$OUT"
echo "Done: $OUT"
