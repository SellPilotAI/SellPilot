# Entity relationship overview

High-level view of how the main entities relate. For full column definitions see [schema.md](schema.md).

## Diagram (Mermaid)

```mermaid
erDiagram
  users ||--o{ store_members : "has"
  stores ||--o{ store_members : "has"
  users ||--o{ stores : "owns"
  stores ||--o{ categories : "has"
  stores ||--o{ products : "has"
  categories ||--o{ products : "contains"
  products ||--o{ product_variants : "has"
  products ||--o{ product_images : "has"
  stores ||--o{ customers : "has"
  stores ||--o{ orders : "has"
  customers ||--o{ orders : "places"
  orders ||--o{ order_items : "contains"
  products ||--o{ order_items : "referenced by"
  orders ||--o{ order_status_logs : "has"
  stores ||--o{ invoices : "has"
  orders ||--o| invoices : "has"
  stores ||--o{ daily_metrics : "has"
  stores ||--o{ ai_generations : "has"
  products ||--o{ ai_generations : "optional"
  users ||--o{ ai_generations : "created by"
  stores ||--o{ growth_plans : "has"
  growth_plans ||--o{ growth_plan_actions : "has"
  stores ||--o{ automation_rules : "has"
  automation_rules ||--o{ automation_executions : "has"
  users ||--o{ audit_logs : "performed by"
  stores ||--o{ audit_logs : "scope"
```

## Grouped summary

- **Auth & tenants:** `users` → `stores` (owner), `store_members` (user–store–role), `store_invitations`.
- **Catalog:** `stores` → `categories`, `products` → `product_variants`, `product_images`; `tags` and `product_tags` for tagging.
- **Commerce:** `stores` → `customers`, `orders` → `order_items`, `order_status_logs`; `orders` → `invoices`.
- **Analytics:** `stores` → `daily_metrics` (one row per store per day).
- **AI:** `stores` → `ai_generations` (optional `product_id`, `created_by` user).
- **Growth:** `stores` → `growth_plans` → `growth_plan_actions`.
- **Automation:** `stores` → `automation_rules` → `automation_executions`.
- **Audit:** `audit_logs` reference `user_id`, `store_id`, and resource type/id.

All store-scoped tables have a `store_id` foreign key so that tenant isolation is enforced at the schema level.
