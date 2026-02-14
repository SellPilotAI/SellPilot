# API endpoints (v1)

This document defines the SellPilot API contract: versioning, auth, response shapes, and the list of resources and endpoints. For copy-paste examples see [examples.md](examples.md).

## Versioning

- All endpoints are prefixed with `/api/v1/`.
- Version is in the URL path, not in headers. This keeps caching and debugging simple.
- Within v1 we keep backward compatibility: we add optional fields and new endpoints but do not remove or rename existing fields. Breaking changes (removals, renames, type changes) require a new major version (e.g. `/api/v2/`).

## Authentication flow

1. **Register:** `POST /api/v1/auth/register/`  
   Body: `{ "email", "password", "name" }`  
   Response: `{ "user", "message" }` (and optionally tokens; see [authentication.md](authentication.md)).

2. **Login:** `POST /api/v1/auth/login/`  
   Body: `{ "email", "password" }`  
   Response: `{ "access", "refresh", "user" }`.

3. **Authenticated requests:** Send the access token in the header:  
   `Authorization: Bearer <access_token>`.

4. **Refresh:** `POST /api/v1/auth/refresh/`  
   Body: `{ "refresh": "<refresh_token>" }`  
   Response: `{ "access" }`.

Details (token lifetime, storage, logout) are in [authentication.md](authentication.md).

## Store-scoped resources

All ecommerce resources are scoped by store so that multi-tenant isolation is enforced at the URL level:

```
/api/v1/stores/{store_id}/{resource}/
```

Example: `GET /api/v1/stores/550e8400-e29b-41d4-a716-446655440000/products/` lists products for that store only. The API validates that the authenticated user is a member of that store (via `X-Store-ID` or context) and returns 403 if not.

## Standard response format

Success responses use this shape:

```json
{
  "data": { ... },
  "meta": {
    "pagination": { "current_page": 1, "total_pages": 5, "total_count": 87, "per_page": 20 },
    "timestamp": "2026-02-12T14:30:00Z"
  },
  "errors": null
}
```

- `data`: the payload (object or array).
- `meta`: optional; includes `pagination` for list endpoints and `timestamp` (ISO 8601).
- `errors`: null on success; populated only on error (see below).

## Error response format

Errors return an appropriate HTTP status and a body like:

```json
{
  "errors": [
    {
      "code": "VALIDATION_ERROR",
      "message": "Invalid email format",
      "field": "email"
    }
  ],
  "meta": {
    "timestamp": "2026-02-12T14:30:00Z",
    "request_id": "req_abc123"
  }
}
```

- `errors`: array of objects with `code`, `message`, and optional `field`.
- Common codes: `VALIDATION_ERROR`, `AUTHENTICATION_FAILED`, `PERMISSION_DENIED`, `NOT_FOUND`, `RATE_LIMIT_EXCEEDED`.

## Pagination

List endpoints use offset-based pagination by default:

- Query: `?page=1&page_size=20` (page_size optional; default 20).
- Response `meta.pagination`: `current_page`, `total_pages`, `total_count`, `per_page`.

## Resource list

### Auth

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register/` | Register a new user. |
| POST | `/api/v1/auth/login/` | Log in; returns access and refresh tokens. |
| POST | `/api/v1/auth/refresh/` | Exchange refresh token for new access token. |
| POST | `/api/v1/auth/logout/` | Invalidate refresh token (if blacklist is used). |

### Stores

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/` | List stores the user is a member of. |
| POST | `/api/v1/stores/` | Create a store (user becomes owner). |
| GET | `/api/v1/stores/{store_id}/` | Retrieve a store. |
| PATCH | `/api/v1/stores/{store_id}/` | Update store (owner/staff). |
| GET | `/api/v1/stores/{store_id}/members/` | List store members. |
| POST | `/api/v1/stores/{store_id}/members/` | Invite a member (owner/staff). |
| DELETE | `/api/v1/stores/{store_id}/members/{user_id}/` | Remove member or leave. |

### Products

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/products/` | List products (filter: status, category; search, sort). |
| POST | `/api/v1/stores/{store_id}/products/` | Create product (with variants/images as needed). |
| GET | `/api/v1/stores/{store_id}/products/{id}/` | Product detail. |
| PATCH | `/api/v1/stores/{store_id}/products/{id}/` | Update product. |
| DELETE | `/api/v1/stores/{store_id}/products/{id}/` | Delete product. |
| GET | `/api/v1/stores/{store_id}/categories/` | List categories. |
| POST | `/api/v1/stores/{store_id}/categories/` | Create category. |
| GET | `/api/v1/stores/{store_id}/categories/{id}/` | Category detail. |
| PATCH | `/api/v1/stores/{store_id}/categories/{id}/` | Update category. |

### Orders

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/orders/` | List orders (filter: status, date range). |
| POST | `/api/v1/stores/{store_id}/orders/` | Create order. |
| GET | `/api/v1/stores/{store_id}/orders/{id}/` | Order detail. |
| PATCH | `/api/v1/stores/{store_id}/orders/{id}/` | Update order (e.g. status, tracking). |
| POST | `/api/v1/stores/{store_id}/orders/{id}/status/` | Transition order status (with validation). |

### Customers

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/customers/` | List customers. |
| POST | `/api/v1/stores/{store_id}/customers/` | Create customer. |
| GET | `/api/v1/stores/{store_id}/customers/{id}/` | Customer detail (with order history). |
| PATCH | `/api/v1/stores/{store_id}/customers/{id}/` | Update customer. |

### Analytics

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/analytics/overview/` | Dashboard overview (revenue, orders, AOV, top products). Query: `period=7d|30d|90d`. |
| GET | `/api/v1/stores/{store_id}/analytics/revenue/` | Revenue series (daily/weekly). Query: `from`, `to`, `granularity`. |

### AI (marketing_ai)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/stores/{store_id}/ai/generate/description/` | Generate product description. Body: `product_id`, `tone`, `length`. |
| POST | `/api/v1/stores/{store_id}/ai/generate/caption/` | Generate social caption. Body: `product_id`, `platform`, `tone`. |
| GET | `/api/v1/stores/{store_id}/ai/generations/` | List past generations (optional filters). |

### Automation

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/automation/rules/` | List automation rules. |
| POST | `/api/v1/stores/{store_id}/automation/rules/` | Create rule (trigger_type, trigger_config, action_type, action_config). |
| GET | `/api/v1/stores/{store_id}/automation/rules/{id}/` | Rule detail. |
| PATCH | `/api/v1/stores/{store_id}/automation/rules/{id}/` | Update rule. |
| DELETE | `/api/v1/stores/{store_id}/automation/rules/{id}/` | Delete rule. |
| GET | `/api/v1/stores/{store_id}/automation/executions/` | List executions (optional filter by rule). |

### Invoices

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/stores/{store_id}/invoices/` | List invoices (optional filter by order). |
| GET | `/api/v1/stores/{store_id}/invoices/{id}/` | Invoice detail and download URL. |
| POST | `/api/v1/stores/{store_id}/orders/{order_id}/invoice/` | Trigger invoice generation (async); returns invoice record when ready or pending. |

Request/response field details for each resource follow the [database schema](../database/schema.md) and are illustrated in [examples.md](examples.md).
