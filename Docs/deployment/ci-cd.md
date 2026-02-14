# CI/CD

SellPilot uses GitHub Actions for continuous integration and deployment. Workflows live under `.github/workflows/`.

## CI (on every push / PR)

- **backend-ci.yml:** Runs on changes under `backend/`. Sets up Python, PostgreSQL (service container), installs dependencies, runs `manage.py check` and `pytest`. Protects `main` and `develop`.
- **frontend-ci.yml:** Runs on changes under `frontend/`. Sets up Node, installs dependencies, runs `npm run lint` and `npm run build`. Protects `main` and `develop`.

PRs targeting `develop` (or `main`) must pass these jobs. No deployment is triggered by CI alone.

## CD (deployment)

- **deploy-staging.yml:** Triggered on push to `develop` or manually. Placeholder steps; in Phase 3/8 it will build Docker images, push to a registry (e.g. ECR), and update the staging environment (e.g. ECS service or EC2).
- **deploy-production.yml:** Triggered manually only. Placeholder; in Phase 8 it will deploy to production with the same pattern as staging, plus any approval or extra checks.

Deployment steps should:

1. Run tests (or rely on branch protection requiring passing CI).
2. Build and tag images.
3. Push to the container registry.
4. Run database migrations (against the target env DB).
5. Update the running service (new task definition, or pull new image on EC2).

Secrets (registry credentials, AWS credentials, DB URLs) are stored in GitHub Secrets and passed into the workflow. They are never logged or committed.

## Branch policy

- **develop:** Integration branch. Feature branches merge here. CI runs; staging deploys from here.
- **main:** Production-ready. Merges from `develop` (or hotfix branches). Production deploys from here. Require PR reviews and passing CI before merge.

Creating a GitHub Project board for phases and issues is done in the GitHub UI and is recommended for tracking Phase 0–8 work.
