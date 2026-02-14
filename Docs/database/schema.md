# Database schema

This document defines the SellPilot database schema: principles, evolution rules, and the full set of tables used by the application.

## Core principles

- **Primary keys:** All tables use UUIDs (`gen_random_uuid()`) for primary keys. This avoids sequential leakage and works well with distribution and caching.
- **Timestamps:** Every table has `created_at` and `updated_at` (or equivalent) so we can reason about when rows were created or changed.
- **Soft deletes:** Where we need to retain data for compliance or history (e.g. orders, audit), we use a `deleted_at` or `is_deleted` pattern instead of hard deletes. Where not required, we use hard deletes and CASCADE.
- **Foreign keys:** All relationships are enforced with foreign keys. This keeps referential integrity and prevents orphaned rows.
- **Indexes:** We add indexes for columns used in filters, joins, and ordering. Partial indexes are used where a subset of rows is queried often (e.g. `WHERE is_active = true`).

## Schema evolution

- All changes are applied via Django migrations (or equivalent versioned migrations). No ad-hoc SQL in production.
- Migrations are written to be reversible where possible (`RunPython` with a reverse function, or reversible operations).
- We avoid migrations that drop data; we deprecate first, then remove in a later migration.
- We maintain backward compatibility for at least one API version when changing response shapes or fields.

---

## 1. Auth and multi-tenancy

### users

Platform users (sellers, staff). Authentication is email + password; JWT for API access.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200),
    is_active BOOLEAN DEFAULT true,
    is_staff BOOLEAN DEFAULT false,
    email_verified BOOLEAN DEFAULT false,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;
```

### stores

Multi-tenant core. Each store is owned by one user and has its own products, orders, and settings.

```sql
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    description TEXT,
    industry VARCHAR(100),
    currency VARCHAR(3) DEFAULT 'USD',
    timezone VARCHAR(50) DEFAULT 'UTC',
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stores_owner ON stores(owner_id);
CREATE INDEX idx_stores_slug ON stores(slug);
CREATE INDEX idx_stores_active ON stores(is_active) WHERE is_active = true;
```

### store_members

RBAC: which users can access which store and with what role (owner, staff, viewer).

```sql
CREATE TABLE store_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'staff', 'viewer')),
    permissions JSONB DEFAULT '{}',
    invited_by UUID REFERENCES users(id),
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, user_id)
);

CREATE INDEX idx_store_members_store ON store_members(store_id);
CREATE INDEX idx_store_members_user ON store_members(user_id);
CREATE INDEX idx_store_members_role ON store_members(store_id, role);
```

### store_invitations

Pending invitations to join a store (email + role). Optional; supports invite flow before user exists.

```sql
CREATE TABLE store_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('staff', 'viewer')),
    token VARCHAR(64) UNIQUE NOT NULL,
    invited_by UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, email)
);

CREATE INDEX idx_store_invitations_store ON store_invitations(store_id);
CREATE INDEX idx_store_invitations_token ON store_invitations(token);
CREATE INDEX idx_store_invitations_expires ON store_invitations(expires_at) WHERE accepted_at IS NULL;
```

### jwt_refresh_blacklist

Blacklisted refresh tokens after logout or rotation (when using blacklist-after-rotation). Optional if your JWT library supports it.

```sql
CREATE TABLE jwt_refresh_blacklist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id VARCHAR(255) NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_jwt_blacklist_token ON jwt_refresh_blacklist(token_id);
CREATE INDEX idx_jwt_blacklist_expires ON jwt_refresh_blacklist(expires_at);
```

---

## 2. Products

### categories

Hierarchical categories per store (e.g. Clothing > T-Shirts).

```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    position INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, slug)
);

CREATE INDEX idx_categories_store ON categories(store_id);
CREATE INDEX idx_categories_parent ON categories(parent_id);
```

### products

Product catalog; one row per product. Variants and images are separate tables.

```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    title VARCHAR(300) NOT NULL,
    description TEXT,
    sku VARCHAR(100),
    base_price DECIMAL(10, 2) NOT NULL,
    compare_at_price DECIMAL(10, 2),
    cost_per_item DECIMAL(10, 2),
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
    meta_title VARCHAR(200),
    meta_description TEXT,
    weight_kg DECIMAL(10, 3),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_store ON products(store_id);
CREATE INDEX idx_products_store_status ON products(store_id, status);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_created ON products(store_id, created_at DESC);
```

### product_variants

Size/color/etc. variants; each has its own SKU, price adjustment, and stock.

```sql
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_name VARCHAR(100) NOT NULL,
    sku VARCHAR(100) UNIQUE,
    price_adjustment DECIMAL(10, 2) DEFAULT 0.00,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 10,
    attributes JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_product_variants_product ON product_variants(product_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_product_variants_stock ON product_variants(product_id, stock_quantity);
```

### product_images

Images for a product; one can be marked primary.

```sql
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(200),
    position INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_product_images_product ON product_images(product_id);
```

### tags

Reusable tags (e.g. "sale", "new") for filtering and search.

```sql
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, slug)
);

CREATE INDEX idx_tags_store ON tags(store_id);
```

### product_tags

Many-to-many between products and tags.

```sql
CREATE TABLE product_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(product_id, tag_id)
);

CREATE INDEX idx_product_tags_product ON product_tags(product_id);
CREATE INDEX idx_product_tags_tag ON product_tags(tag_id);
```

---

## 3. Customers

### customers

Customer records per store (buyers). Linked to orders for history and segmentation.

```sql
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    default_shipping_address JSONB,
    default_billing_address JSONB,
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_store ON customers(store_id);
CREATE INDEX idx_customers_email ON customers(store_id, email) WHERE email IS NOT NULL;
```

---

## 4. Orders

### orders

An order belongs to a store and a customer; totals and status live here.

```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    subtotal DECIMAL(10, 2) NOT NULL,
    tax DECIMAL(10, 2) DEFAULT 0.00,
    shipping_cost DECIMAL(10, 2) DEFAULT 0.00,
    total DECIMAL(10, 2) NOT NULL,
    shipping_address JSONB,
    billing_address JSONB,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_orders_store ON orders(store_id);
CREATE INDEX idx_orders_store_status ON orders(store_id, status);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_created ON orders(created_at DESC);
CREATE INDEX idx_orders_number ON orders(order_number);
```

### order_items

Line items: product, variant, quantity, unit price, line total.

```sql
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    line_total DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
```

### order_status_logs

History of status changes for an order (for audit and display).

```sql
CREATE TABLE order_status_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    from_status VARCHAR(20),
    to_status VARCHAR(20) NOT NULL,
    note TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_status_logs_order ON order_status_logs(order_id);
CREATE INDEX idx_order_status_logs_created ON order_status_logs(order_id, created_at DESC);
```

---

## 5. Invoices

### invoices

Generated invoice metadata and storage key for the PDF.

```sql
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL,
    file_url VARCHAR(500),
    file_key VARCHAR(500),
    total DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'generated', 'failed')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, invoice_number)
);

CREATE INDEX idx_invoices_store ON invoices(store_id);
CREATE INDEX idx_invoices_order ON invoices(order_id);
CREATE INDEX idx_invoices_created ON invoices(store_id, created_at DESC);
```

---

## 6. Analytics

### daily_metrics

Pre-aggregated metrics per store per day (revenue, order count, AOV, etc.). Populated by a nightly Celery task.

```sql
CREATE TABLE daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    revenue DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    orders_count INTEGER NOT NULL DEFAULT 0,
    new_customers INTEGER NOT NULL DEFAULT 0,
    returning_customers INTEGER NOT NULL DEFAULT 0,
    avg_order_value DECIMAL(10, 2),
    units_sold INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, date)
);

CREATE INDEX idx_daily_metrics_store_date ON daily_metrics(store_id, date DESC);
```

---

## 7. AI (marketing_ai)

### ai_generations

Record of each AI-generated content (description, caption, ad, etc.) for history and reuse.

```sql
CREATE TABLE ai_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL,
    tone VARCHAR(50),
    prompt_text TEXT NOT NULL,
    output_text TEXT NOT NULL,
    tokens_used INTEGER,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ai_generations_store ON ai_generations(store_id);
CREATE INDEX idx_ai_generations_store_type ON ai_generations(store_id, type);
CREATE INDEX idx_ai_generations_created ON ai_generations(created_at DESC);
```

### prompt_templates

Stored prompt templates (e.g. product description, caption) with placeholders. Optional; can be code-only initially.

```sql
CREATE TABLE prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    template_body TEXT NOT NULL,
    variables JSONB DEFAULT '[]',
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prompt_templates_store ON prompt_templates(store_id);
CREATE INDEX idx_prompt_templates_slug ON prompt_templates(slug) WHERE is_system = true;
```

---

## 8. Growth agent

### growth_plans

Weekly (or periodic) growth plans generated by the agent.

```sql
CREATE TABLE growth_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    plan_type VARCHAR(50) NOT NULL DEFAULT 'weekly',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    summary TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed')),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_growth_plans_store ON growth_plans(store_id);
CREATE INDEX idx_growth_plans_period ON growth_plans(store_id, period_start, period_end);
```

### growth_plan_actions

Individual actions (e.g. “Post about product X”, “Email lapsed customers”) within a plan.

```sql
CREATE TABLE growth_plan_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES growth_plans(id) ON DELETE CASCADE,
    day_index INTEGER NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    config JSONB DEFAULT '{}',
    content_generated TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'skipped')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_growth_plan_actions_plan ON growth_plan_actions(plan_id);
```

---

## 9. Automation

### automation_rules

Trigger + action rules (e.g. when stock low → send email).

```sql
CREATE TABLE automation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    trigger_type VARCHAR(50) NOT NULL,
    trigger_config JSONB NOT NULL DEFAULT '{}',
    action_type VARCHAR(50) NOT NULL,
    action_config JSONB NOT NULL DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_automation_rules_store ON automation_rules(store_id);
CREATE INDEX idx_automation_rules_active ON automation_rules(store_id, is_active) WHERE is_active = true;
```

### automation_executions

Log of each rule execution (success/failure, payload). Used for debugging and auditing.

```sql
CREATE TABLE automation_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES automation_rules(id) ON DELETE CASCADE,
    triggered_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'failure', 'timeout')),
    payload JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_automation_executions_rule ON automation_executions(rule_id);
CREATE INDEX idx_automation_executions_triggered ON automation_executions(triggered_at DESC);
```

---

## 10. Audit

### audit_logs

Who did what, when, and where (store, resource). Required for mutations; stores old/new values for updates.

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    store_id UUID REFERENCES stores(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent VARCHAR(500),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_store ON audit_logs(store_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(store_id, resource_type, resource_id);
```

---

## 11. Optional / future

### webhook_endpoints

Store-defined webhook URLs for order/event notifications. Optional for Phase 0.

```sql
CREATE TABLE webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    secret VARCHAR(64),
    events JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_webhook_endpoints_store ON webhook_endpoints(store_id);
```

### webhook_deliveries

Log of each webhook delivery attempt (success/failure, response code). Optional.

```sql
CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint_id UUID NOT NULL REFERENCES webhook_endpoints(id) ON DELETE CASCADE,
    event VARCHAR(100) NOT NULL,
    payload JSONB,
    response_code INTEGER,
    response_body TEXT,
    success BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_webhook_deliveries_endpoint ON webhook_deliveries(endpoint_id);
CREATE INDEX idx_webhook_deliveries_created ON webhook_deliveries(created_at DESC);
```

---

Total: **32 tables** (including optional jwt_refresh_blacklist, store_invitations, prompt_templates, webhook_endpoints, webhook_deliveries). Core tables are required for Phases 1–2; AI, growth, automation, and webhook tables align with later phases.
