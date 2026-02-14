# Security model

This document summarizes SellPilot’s security posture at a high level. Tenant isolation and audit are covered in [multi-tenancy.md](multi-tenancy.md); here we focus on authentication, authorization, input handling, transport, and secrets.

## Authentication

- **API:** JWT-based. Access tokens are short-lived; refresh tokens are used to obtain new access tokens. See [authentication.md](../api/authentication.md) for the flow. Passwords are hashed with a secure algorithm (e.g. PBKDF2 or Argon2) and never stored or logged in plain text.
- **Sessions:** The dashboard can use the same JWT (stored in memory or httpOnly cookie) or a separate session store. Session fixation and CSRF are mitigated (e.g. CSRF middleware and SameSite cookies).

## Authorization (RBAC)

- **Stores:** Each store has members with roles: owner, staff, viewer. Permissions (who can edit products, who can delete the store, etc.) are defined in code and checked via DRF permission classes and, where needed, object-level checks.
- **API:** Every store-scoped request is validated so that the authenticated user is a member of the store indicated by `X-Store-ID`. No cross-tenant access is allowed. See [multi-tenancy.md](multi-tenancy.md).

## Input validation and sanitization

- **API:** All request bodies and query parameters are validated via serializers or schema validation. Invalid or unexpected types are rejected with 400. String length and format (e.g. email, UUID) are enforced.
- **Storage and display:** User-controlled data is stored as given (no arbitrary HTML in DB). When rendered in the dashboard, we use safe escaping (e.g. React’s default escaping) so that XSS is not introduced. File uploads are validated (type, size) and stored with safe names and content types.

## Audit logging

- All mutations (create, update, delete) on important resources are logged to the audit log with user, store, action, resource, and when possible old/new values. This supports compliance and incident response. Details are in [multi-tenancy.md](multi-tenancy.md).

## Transport and TLS

- Production traffic is over HTTPS only. TLS 1.2+ is enforced; certificates are managed via a known provider (e.g. Let’s Encrypt or AWS ACM). We avoid sending tokens or sensitive data in URLs; they go in headers or request body.

## Secrets and configuration

- **Application secrets** (e.g. Django `SECRET_KEY`, JWT signing key, DB password) are not committed to the repo. They are supplied via environment variables or a secrets manager (e.g. AWS Secrets Manager) in production.
- **Per-environment:** Development, staging, and production use different configs and secrets. Debug mode and verbose errors are disabled in production.

## Dependencies

- We keep backend and frontend dependencies up to date and respond to known vulnerabilities (e.g. via Dependabot or similar). Production images are built from pinned versions.

This gives a single place to understand how we handle auth, RBAC, input safety, audit, TLS, and secrets. For the exact mechanics of tenant isolation, see [multi-tenancy.md](multi-tenancy.md).
