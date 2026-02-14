# System Design

This document describes the high-level architecture of SellPilot: the main components, how they talk to each other, a few concrete data flows, and how we scale.

## System components

**Client tier.** Browsers and mobile web clients. We don’t ship a native mobile app; the dashboard is responsive so sellers can use it on phones and tablets. All client traffic is over HTTPS.

**Application tier.** Next.js frontend. It serves the dashboard UI, does server-side rendering where it helps, and talks to the API on the backend. We keep business logic and data access in the API, not in the frontend.

**API tier.** Django REST Framework. It handles auth (JWT), request validation, store-scoped access, and calls into the database, cache, and task queue. It’s stateless so we can run multiple instances behind a load balancer.

**Data tier.** PostgreSQL. All persistent data lives here: users, stores, products, orders, customers, analytics aggregates, AI generations, automation rules, audit logs. We use UUIDs for primary keys and enforce relationships with foreign keys.

**Cache tier.** Redis. We use it for session data, rate limiting, and caching expensive queries (e.g. analytics). Using Redis for both cache and the Celery broker keeps the stack simple; we can split them later if needed.

**Task queue.** Celery with Redis as the broker. Heavy or asynchronous work runs here: daily metrics aggregation, invoice PDF generation, email sending, AI content generation, automation actions. Workers scale independently from the API.

**Storage tier.** S3. Product images, invoice PDFs, and other media are stored in S3. The API generates pre-signed URLs for uploads and serves download URLs. We don’t stream large files through the API servers.

**CDN tier.** CloudFront in front of S3 for static and media assets. It reduces latency and offloads bandwidth from the origin.

## Communication protocols

| From → To            | Protocol / auth        | Notes                                      |
|----------------------|------------------------|--------------------------------------------|
| Client → Frontend    | HTTPS                  | WebSocket planned for live updates later   |
| Frontend → API       | REST over HTTPS, JWT   | `Authorization: Bearer <access_token>`     |
| API → Database       | PostgreSQL protocol    | Connection pooling (e.g. PgBouncer) in prod |
| API → Cache          | Redis protocol         | Same Redis for cache and Celery broker     |
| API → Task queue     | Redis (Celery broker)  | Tasks enqueued via Celery, no direct AMQP  |
| API → S3             | AWS SDK (HTTPS)        | IAM roles in production                    |

## Data flow examples

**1. User uploads a product image.** The frontend requests a pre-signed URL from the API. The API generates the URL (using the store’s bucket path and credentials), returns it to the client, and the client uploads the file directly to S3. After the upload, the client calls the API again to create a `product_images` row that stores the S3 key and links it to the product. The image is served later via CloudFront.

**2. Customer places an order.** The client sends the order payload to the API. The API validates it, writes the order and order items to the database, updates inventory, and enqueues a Celery task to send the confirmation email and generate the invoice PDF. The response is returned immediately; the email and PDF are produced asynchronously.

**3. Seller opens the analytics dashboard.** The frontend calls the API for the analytics overview (e.g. revenue, order count, top products). The API checks Redis for a cached result for that store and date range. On a miss, it reads from the `daily_metrics` table (and any live aggregates), builds the response, caches it in Redis, and returns it. Subsequent requests for the same range are served from cache until TTL expires.

## Scaling strategy

**API servers.** Stateless; we run N instances behind a load balancer and add more as traffic grows. No sticky sessions required.

**Database.** We start with a single PostgreSQL instance. When read load grows, we add read replicas and direct reporting/analytics queries to them. Writes stay on the primary.

**Redis.** Single instance is enough initially. For higher availability and throughput we move to a Redis cluster or managed ElastiCache with replication.

**CDN.** CloudFront is already distributed; we configure cache TTLs per path (e.g. product images 24h, invoices shorter).

**Celery workers.** We scale worker processes or containers separately from the API. High-priority queues (e.g. order confirmation) can get dedicated workers; batch jobs (e.g. nightly metrics) can use a lower-priority queue.

All of this is documented so that when we hit limits we know where to add capacity without redesigning the system.
