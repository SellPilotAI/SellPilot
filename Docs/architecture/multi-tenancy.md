# Multi-tenancy security model

SellPilot is a multi-tenant SaaS application: many stores (tenants) share the same application and database. This document describes how we isolate tenant data and enforce access at every layer.

## Tenant isolation strategy

We use **row-level multi-tenancy**. A single PostgreSQL database holds all tenants; every row that belongs to a store has a `store_id` (or equivalent) foreign key. The application enforces isolation by always filtering and scoping by store. The database enforces referential integrity so that store-scoped rows cannot reference another store’s data.

**Why row-level?**

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Separate DB per tenant | Strong isolation, easy to move a tenant | Costly, migrations and ops scale with tenant count | Rejected |
| Schema per tenant | Good isolation | Schema migrations and backups are complex | Rejected |
| Row-level (shared DB, store_id on rows) | One schema, one deployment, simple migrations | Requires strict application-level filtering | **Chosen** |

Row-level lets us deploy one schema, run one migration set, and scale the database as a single unit. The tradeoff is that we must never forget to scope by store; the layers below are there to make that systematic.

## Enforcement layers

We enforce tenant isolation in four places so that a mistake in one layer is caught by another.

### 1. Middleware

Request-level store context is set in middleware. The frontend sends the current store in the `X-Store-ID` header. The middleware resolves the user from the JWT, then checks that the user is a member of that store.

```python
class StoreContextMiddleware:
    def __call__(self, request):
        if request.user.is_authenticated:
            store_id = request.headers.get("X-Store-ID")
            if store_id:
                membership = StoreMember.objects.filter(
                    store_id=store_id,
                    user_id=request.user.id,
                ).select_related("store").first()

                if membership:
                    request.store = membership.store
                    request.store_role = membership.role
                else:
                    request.store = None
                    request.store_role = None
        return self.get_response(request)
```

Views and serializers then use `request.store` and `request.store_role` instead of trusting any store_id from the body or URL path for authorization. The URL path still contains `store_id` so that routing is clear; we validate that it matches `request.store` when the request is store-scoped.

### 2. ORM (query layer)

Store-scoped models inherit from a base that adds a `store` foreign key and a custom manager/queryset that only ever returns rows for a given store.

```python
class StoreOwnedQuerySet(models.QuerySet):
    def for_store(self, store):
        return self.filter(store=store)


class StoreOwnedModel(models.Model):
    store = models.ForeignKey(Store, on_delete=models.CASCADE)
    objects = StoreOwnedQuerySet.as_manager()

    class Meta:
        abstract = True
```

Views (or services) call `Model.objects.for_store(request.store)` so that listing and retrieval never cross store boundaries. New rows are created with `store=request.store` so the FK is set consistently.

### 3. Permissions

DRF permission classes enforce that the request has store context and that the user’s role is allowed to perform the action.

```python
class IsStoreMember(permissions.BasePermission):
    def has_permission(self, request, view):
        return hasattr(request, "store") and request.store is not None


class IsStoreOwner(permissions.BasePermission):
    def has_permission(self, request, view):
        return (
            hasattr(request, "store") and
            request.store is not None and
            getattr(request, "store_role", None) == "owner"
        )
```

Store-scoped views use `IsStoreMember` by default; actions that only owners (or staff) can do use `IsStoreOwner` or a custom permission that checks `store_role`.

### 4. Serializers

Serializers ensure that the store on create/update is the one from the request context, not from the payload.

```python
class ProductSerializer(serializers.ModelSerializer):
    def validate(self, attrs):
        request = self.context.get("request")
        if request and hasattr(request, "store"):
            if attrs.get("store") and attrs["store"] != request.store:
                raise serializers.ValidationError(
                    "Cannot create or update product for a different store."
                )
            attrs["store"] = request.store
        return attrs
```

So even if the client sends a different `store_id`, the saved record is tied to the store the user is actually in.

## Audit requirements

Every mutation (create, update, delete) that touches store or user data must write an audit log entry. Each entry records:

- **Who:** `user_id`
- **What:** action type (e.g. `product.create`, `order.update`)
- **When:** timestamp
- **Where:** `store_id`, `resource_type`, `resource_id`
- **Changes:** for updates, `old_values` and `new_values` (or a summary)

This supports compliance, debugging, and security reviews. The schema for `audit_logs` is in [schema.md](../database/schema.md).

Example log entry (conceptual):

```json
{
  "user_id": "usr_abc",
  "store_id": "str_xyz",
  "action": "product.update",
  "resource_type": "product",
  "resource_id": "prd_123",
  "old_values": { "base_price": "29.99", "status": "active" },
  "new_values": { "base_price": "24.99", "status": "active" },
  "created_at": "2026-02-12T14:30:00Z"
}
```

## Cross-tenant rules

- **No cross-tenant reads.** Queries must always be scoped by `request.store` (or the store implied by the resource). There are no “superuser” queries that return data across stores unless they are explicit admin/analytics pipelines with their own controls.
- **No cross-tenant writes.** Create/update payloads must not allow setting `store_id` to a store the user is not a member of. The serializer layer enforces this by overwriting `store` from the request context.
- **Store resolution.** The store is taken from the `X-Store-ID` header for store-scoped endpoints. The middleware validates membership; if the header is missing or invalid, `request.store` is `None` and permission checks fail. We do not derive store from the JWT alone so that the client explicitly chooses the active store (e.g. after switching stores in the UI).

With these layers and rules, tenant isolation is enforced at middleware, ORM, permission, and serializer level, and all mutations are audited.
