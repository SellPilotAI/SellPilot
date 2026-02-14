# Contributing to SellPilot

Thanks for your interest in contributing. This document covers how we work and what we expect from patches.

## Getting started

1. Fork the repo and clone it.
2. Set up the project: see [README](README.md) and `docs/deployment/docker.md` for local setup.
3. Create a branch from `develop` (or `main` if you’re fixing a doc/typo): `feature/short-name` or `bugfix/short-name`.

## Branch naming

- `feature/<name>` — new features
- `bugfix/<name>` — bug fixes
- `hotfix/<name>` — urgent production fixes (from `main`)

We use `develop` as the integration branch; `main` is for production-ready releases.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(scope): description`
- `fix(scope): description`
- `docs: description`
- `refactor(scope): description`
- `test(scope): description`
- `chore: description`

Example: `feat(products): add bulk CSV import`.

## Pull requests

1. Open a PR against `develop` (or `main` for hotfixes).
2. Fill in the PR template; describe what changed and why.
3. Ensure CI passes (backend tests, frontend lint/build).
4. Request review; address feedback.
5. We squash-merge once approved.

## Code standards

- **Backend:** See `docs/development/standards.md` (PEP 8, Black, isort, tests).
- **Frontend:** Same doc (ESLint, Prettier, TypeScript, tests).
- **Docs:** Update any affected docs or API specs when you change behavior.

## Testing

- Backend: `cd backend && pytest`
- Frontend: `cd frontend && npm run lint && npm run build`
- Keep coverage above 80% for new code where practical.

## Questions

Open an issue with the question label or start a discussion. For security issues, prefer a private channel if your project has one.
