# Database migrations

SellPilot uses Django migrations to evolve the database schema. This document describes how we run, roll back, and review migrations.

## Running migrations

**Local / dev:**

```bash
cd backend
python manage.py migrate
```

This applies all unapplied migrations in order. Use `python manage.py showmigrations` to see which are applied.

**Staging / production:**  
Migrations are run as part of the deployment process (e.g. in CI or a release job) before the new application code is deployed. We run them against the target database using the same Django `migrate` command, with the environment’s `DATABASE_URL` or DB_* variables set.

**Safety:**  
Run `python manage.py migrate --check` in CI to ensure there are no unapplied migrations before deployment. Failing this check blocks the release.

## Creating migrations

After changing models:

```bash
python manage.py makemigrations
```

Review the generated migration file. Ensure it only includes the intended changes and that default values or nullability are set so existing rows are handled (e.g. new non-null column with a default, or nullable first then backfill then make non-null in a follow-up).

**Naming:**  
Django auto-generates names like `0002_product_sku.py`. Keep migrations small and focused so rollbacks are predictable.

## Rollback

To undo the last migration for an app:

```bash
python manage.py migrate app_name <previous_migration_name>
```

Example: `python manage.py migrate products 0001_initial` reverts products to the first migration.

**Data loss:**  
Migrations that remove columns or tables can drop data. We avoid irreversible data loss: prefer adding a new column and deprecating the old one over renaming in one step if the table is large. For sensitive rollbacks, take a backup first.

## Backward compatibility

When changing the schema, we keep the app backward compatible for at least one deploy: e.g. we add a new column as nullable or with a default, deploy, then in a later migration we enforce non-null or remove the old column. This allows a rolling deploy where old and new code can run against the same database.

## Summary

- All schema changes go through migrations. No ad-hoc SQL in production.
- Migrations run before new code is deployed.
- Migrations are reversible where possible; we avoid one-step migrations that drop data.
- New columns are added in a way that doesn’t break existing code (nullable or default, then tighten in a follow-up).
