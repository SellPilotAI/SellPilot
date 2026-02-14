# Authentication

SellPilot uses JWT (JSON Web Tokens) for API authentication. This document covers the token lifecycle, how to use them, and security considerations.

## Token types

- **Access token:** Short-lived (e.g. 15 minutes). Sent on every API request in the `Authorization: Bearer <access_token>` header. Used to identify the user and authorize access to stores and resources.
- **Refresh token:** Long-lived (e.g. 7 days). Used only to obtain a new access token via `POST /api/v1/auth/refresh/`. Not sent on normal requests.

We use short-lived access tokens to limit the impact of a leaked token. Refresh tokens allow the client to get new access tokens without asking the user to log in again. When refresh rotation is enabled, each use of a refresh token issues a new one and can blacklist the previous one so that reuse is detected.

## Obtaining tokens

**Login:**  
`POST /api/v1/auth/login/` with body `{ "email": "...", "password": "..." }`.  
Response includes `access`, `refresh`, and `user` (id, email, name, etc.). Store the refresh token securely (e.g. httpOnly cookie or secure storage) and use the access token in the `Authorization` header for subsequent requests.

**Refresh:**  
When the access token expires (e.g. 401 response), call `POST /api/v1/auth/refresh/` with body `{ "refresh": "<refresh_token>" }`. Response is `{ "access": "<new_access_token>" }`. Optionally the server returns a new refresh token and blacklists the old one; if so, the client should replace the stored refresh token.

## Using the access token

For every request to a store-scoped or user-scoped endpoint, send:

```
Authorization: Bearer <access_token>
```

If the token is missing, expired, or invalid, the API returns 401 with an error code such as `AUTHENTICATION_FAILED`. If the user is authenticated but not allowed to access the requested store or resource, the API returns 403 with `PERMISSION_DENIED`.

## Store context

For store-scoped endpoints the client must indicate which store is being accessed. We do this via the `X-Store-ID` header set to the store’s UUID. The API validates that the authenticated user is a member of that store (see [multi-tenancy](../architecture/multi-tenancy.md)). If the user has no access, the response is 403.

Example:

```
Authorization: Bearer eyJ...
X-Store-ID: 550e8400-e29b-41d4-a716-446655440000
```

## Logout

If the backend supports refresh token blacklisting, call `POST /api/v1/auth/logout/` with the refresh token (in body or cookie). The server blacklists that token so it can’t be used to get new access tokens. The client should then discard both access and refresh tokens.

If there is no blacklist, “logout” is client-only: discard tokens and optionally call an endpoint that does nothing but forces the client to clear state.

## Security

- **Storage:** Don’t store access or refresh tokens in plain localStorage if the app is exposed to XSS. Prefer memory + refresh in httpOnly cookie, or a secure native store for mobile.
- **HTTPS:** All auth endpoints and API calls must use HTTPS in production so tokens aren’t sent in the clear.
- **Expiry:** Access tokens expire quickly to limit exposure. Refresh tokens have a longer lifetime but should be rotated and, when possible, blacklisted on use or logout.
- **Secrets:** Token signing uses a server-side secret (e.g. `SECRET_KEY` or a dedicated JWT key). Never expose this to the client.

Token lifetime and rotation behavior are configured server-side (e.g. in Django settings for Simple JWT). See the backend configuration for exact values.
