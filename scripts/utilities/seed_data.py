#!/usr/bin/env python
"""
Seed database with sample data for local development.
Usage: from repo root, python scripts/utilities/seed_data.py
Or: cd backend && python ../scripts/utilities/seed_data.py
"""
import os
import sys

# Add backend to path so we can use Django (repo root is two levels up from scripts/utilities)
backend = os.path.join(os.path.dirname(__file__), "..", "..", "backend")
sys.path.insert(0, backend)
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

def main():
    import django
    django.setup()
    # Add seed logic in Phase 2 (stores, products, etc.)
    print("Seed data: add fixtures in Phase 2.")

if __name__ == "__main__":
    main()
