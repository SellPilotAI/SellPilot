# API examples

Copy-paste examples for common flows. Replace placeholders (`YOUR_*`, `store_id`, etc.) with real values. Base URL is assumed to be `https://api.sellpilot.io`; for local dev use `http://localhost:8000`.

## 1. Register

```bash
curl -X POST https://api.sellpilot.io/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "seller@example.com",
    "password": "YourSecurePassword123!",
    "name": "Jane Seller"
  }'
```

Expected response (201): `{ "data": { "user": { "id": "...", "email": "seller@example.com", "name": "Jane Seller" }, "message": "..." }` (tokens may be included depending on implementation).

## 2. Login

```bash
curl -X POST https://api.sellpilot.io/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "seller@example.com",
    "password": "YourSecurePassword123!"
  }'
```

Example response (200):

```json
{
  "data": {
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "user": {
      "id": "usr_abc123",
      "email": "seller@example.com",
      "name": "Jane Seller"
    }
  },
  "meta": { "timestamp": "2026-02-12T14:30:00Z" }
}
```

Save `data.access` for the next requests; use `data.refresh` for refresh (example 3).

## 3. Refresh access token

```bash
curl -X POST https://api.sellpilot.io/api/v1/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{ "refresh": "YOUR_REFRESH_TOKEN" }'
```

Response (200): `{ "data": { "access": "eyJ..." } }` (and optionally a new refresh token).

## 4. Create a store

```bash
curl -X POST https://api.sellpilot.io/api/v1/stores/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "name": "My Store",
    "slug": "my-store",
    "industry": "Fashion",
    "currency": "USD"
  }'
```

Response (201) includes the new store (e.g. `id`, `name`, `slug`). Use `id` as `store_id` in store-scoped requests.

## 5. List products

```bash
curl -X GET "https://api.sellpilot.io/api/v1/stores/STORE_ID/products/?page=1&status=active" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Store-ID: STORE_ID"
```

Replace `STORE_ID` with the store UUID.

## 6. Create a product

```bash
curl -X POST https://api.sellpilot.io/api/v1/stores/STORE_ID/products/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Store-ID: STORE_ID" \
  -d '{
    "title": "Classic White Tee",
    "description": "Premium cotton t-shirt.",
    "base_price": "29.99",
    "status": "active",
    "variants": [
      {
        "variant_name": "Small / White",
        "sku": "CWT-SM-WHT",
        "price_adjustment": "0.00",
        "stock_quantity": 50
      },
      {
        "variant_name": "Medium / White",
        "sku": "CWT-MD-WHT",
        "price_adjustment": "0.00",
        "stock_quantity": 45
      }
    ]
  }'
```

## 7. List orders

```bash
curl -X GET "https://api.sellpilot.io/api/v1/stores/STORE_ID/orders/?status=processing&page=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Store-ID: STORE_ID"
```

## 8. Analytics overview

```bash
curl -X GET "https://api.sellpilot.io/api/v1/stores/STORE_ID/analytics/overview/?period=30d" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Store-ID: STORE_ID"
```

Example response shape: `data` contains `revenue`, `orders`, `avg_order_value`, `top_products`, etc., and `meta.period` / `meta.timestamp`.

## 9. Generate product description (AI)

```bash
curl -X POST https://api.sellpilot.io/api/v1/stores/STORE_ID/ai/generate/description/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Store-ID: STORE_ID" \
  -d '{
    "product_id": "PRODUCT_UUID",
    "tone": "professional",
    "length": "medium"
  }'
```

Response includes `data.output` (generated text) and optionally `data.generation_id`, `data.tokens_used`.

## 10. Error response example

Invalid login (401):

```bash
curl -X POST https://api.sellpilot.io/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{ "email": "wrong@example.com", "password": "wrong" }'
```

Example body:

```json
{
  "errors": [
    { "code": "AUTHENTICATION_FAILED", "message": "Invalid credentials" }
  ],
  "meta": { "timestamp": "2026-02-12T14:30:00Z", "request_id": "req_xyz" }
}
```

Validation error (400) typically includes `field` in each error object so the client can highlight form fields.
