# Phase 2: Generate Stubs

You are generating minimal working stub files for a new project based on patterns from a reference project. You have access to both the reference project and the target project directory.

## Your Task

You will receive:
1. The path to the reference project
2. The path to the target project (already has `copy` and `replace` files in place)
3. A list of files classified as `stub` with guidance on what to keep/remove
4. The new project's name and description

For each stub file, read the reference version, understand the pattern, and write a minimal working version in the target project.

## Stub Generation Rules

### Entities (`lib/entities/*.ts`)
- **Keep:** MikroORM decorators, imports, class structure, `@Entity` decorator with tableName
- **Keep:** Base fields: `id` (PrimaryKey, bigint), `createdAt`, `updatedAt` timestamps
- **Keep:** `Store` entity with: id, providerStoreKey, vendor, name, accessToken, refreshToken, storeUsers collection, createdAt, updatedAt, isActive
- **Keep:** `User` entity with: id, email, name, createdAt, updatedAt
- **Keep:** `StoreUser` entity with: id, store (ManyToOne), user (ManyToOne), providerUserId, role, createdAt
- **Drop:** All domain-specific entities (products, categories, SEO profiles, batch jobs, etc.)
- **Drop:** Domain-specific fields on kept entities
- **Update:** `lib/entities/index.ts` to only export the kept entities

### Repositories (`lib/repositories/*.ts`)
- **Keep:** `StoreRepository` with basic CRUD (findByProviderKey, findOrCreate)
- **Keep:** `UserRepository` with basic CRUD (findByEmail, findOrCreate)
- **Keep:** `StoreUserRepository` with basic operations
- **Drop:** All domain-specific repositories
- **Drop:** Vendor adapter implementations (BigCommerceVendor, ShopifyVendor, etc.)
- Write minimal implementations — just enough to compile

### Pages (`pages/**`)
- **Keep:** `pages/index.tsx` — simple landing page with the new project name
- **Keep:** `pages/_app.tsx` — preserve the app wrapper pattern
- **Keep:** `pages/api/health.ts` — health check endpoint
- **Keep:** `pages/api/auth.ts` or auth routes — preserve OAuth pattern if present
- **Drop:** All domain-specific pages and API routes
- Generated pages should be minimal but functional

### Terraform Root (`terraform/main.tf`)
- **Keep modules:** vpc, cloudsql, iam, memorystore, pgbouncer, secrets, cloudrun, monitoring
- **Drop modules:** scheduler, storage, eventbridge, and any domain-specific modules
- **Keep:** provider blocks, terraform backend configuration
- **Simplify:** Remove batch job configuration from cloudrun module invocation
- **Update:** Variable references to match the kept modules only

### Terraform Variables & Outputs
- **Keep:** Variables for kept modules (database, redis, cloudrun, vpc, monitoring)
- **Drop:** Variables for dropped modules (batch, scheduler, storage)
- **Keep:** Outputs for kept modules
- Ensure variables have sensible defaults

### Components
- **Keep:** Layout components (navigation, app shell)
- **Drop:** All domain-specific components
- Write a minimal main component that shows the project name

### Hooks
- **Keep:** Generic hooks (`useSSE.ts` if present, auth hooks)
- **Drop:** Domain-specific hooks

### Library files
- **Keep:** `lib/auth.ts` — preserve auth pattern
- **Keep:** `lib/cache.ts`, `lib/redis.ts` — infrastructure utilities
- **Keep:** `lib/dbs/` — database initialization
- **Drop:** Domain-specific service files, vendor implementations
- **Drop:** Webhook handlers, job processors, workers

## Writing Rules

1. Every stub file must be valid TypeScript that compiles without errors
2. Preserve import paths — if the reference uses `@lib/entities`, use the same alias
3. Use the same code style as the reference (semicolons, quotes, indentation)
4. Add a `// TODO: Implement for {{PROJECT_NAME}}` comment where domain-specific logic was removed
5. Do NOT generate test files — those come later
6. Do NOT generate migration files — those are auto-generated from entities
7. Maintain the same directory structure as the reference
8. If a stub depends on another stub (e.g., repository imports entity), ensure consistency

## Output

Use the Write tool to create each stub file in the target project directory. After writing all files, output a summary of what was created.
