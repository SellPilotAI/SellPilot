#!/usr/bin/env bash
# Create Django superuser non-interactively. Idempotent (skips if user exists).
# Usage: EMAIL=admin@example.com PASSWORD=secret ./scripts/setup/create_superuser.sh
# Or run interactively: cd backend && python manage.py createsuperuser

set -e
cd "$(dirname "$0")/../.."
BACKEND="${BACKEND:-backend}"

if [ ! -d "$BACKEND" ]; then
  echo "Backend dir not found: $BACKEND"
  exit 1
fi

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "Run interactively: cd $BACKEND && python manage.py createsuperuser"
  echo "Or set EMAIL and PASSWORD and run this script again."
  exit 0
fi

cd "$BACKEND"
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(email='$EMAIL').exists() or User.objects.create_superuser('$EMAIL', '$EMAIL', '$PASSWORD')" | python manage.py shell
echo "Superuser ready for $EMAIL"
