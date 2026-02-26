# Phase 1: Inventory & Plan

You are analyzing a reference project to create a scaffold plan for a new project. Your job is to classify every file in the reference project and produce a structured JSON plan.

## Your Task

1. Explore the reference project thoroughly using Glob and Read
2. Classify every file into one of four categories
3. Identify naming patterns that need find-and-replace
4. Output a single JSON document

## File Classifications

### `copy` — Identical infrastructure files
Files that are the same across all projects. Copy verbatim.
Examples:
- `.gitignore`
- `tsconfig.json`
- `postcss.config.js`
- `tailwind.config.js`
- `eslint.config.mjs`
- Terraform modules (`terraform/modules/**`) — these are reusable infrastructure building blocks
- Vitest configs (`vitest.config*.ts`)
- Test setup files (`test/setup/**`)
- Shared library utilities (`lib/utils/**`, `lib/errors/**`, `lib/cache.ts`, `lib/redis.ts`)
- CI/CD workflows (`.github/workflows/**`)
- VS Code settings (`.vscode/**`)
- Script utilities that are project-agnostic (`scripts/attach_to_db.sh`, `scripts/deploy.sh`, etc.)

### `replace` — Same structure, project names need replacing
Files that have the same structure but contain project-specific names (package name, GCP project IDs, service names, domains, database names).
Examples:
- `package.json` — project name, description, homepage
- `terraform/environments/*/terraform.tfvars` — project IDs, service names, bucket names
- `terraform/main.tf` — may reference project-specific module configs
- `terraform/variables.tf` — default values with project names
- `.env.example` or `.env.local` — project-specific env vars
- Deploy scripts that reference project names
- `mikro-orm.config.ts` — database name
- `next.config.js` — if it contains project-specific values

### `stub` — Shared pattern, app-specific content
Files where the structure/pattern should be preserved but the specific content is app-specific. Claude will generate minimal working versions in Phase 2.
Examples:
- Entity files (`lib/entities/*.ts`) — keep base fields (id, timestamps, relations to Store), drop domain-specific fields
- Repository files (`lib/repositories/*.ts`) — keep structure, make generic
- `pages/index.tsx` — keep layout pattern, replace content
- `terraform/main.tf` — keep shared modules (vpc, cloudsql, iam, memorystore, pgbouncer, secrets, cloudrun, monitoring), drop app-specific ones
- `terraform/outputs.tf` — keep outputs for shared modules only
- Main page components
- `lib/entities/index.ts` — re-export only the stubbed entities

### `skip` — Entirely app-specific
Files that are unique to the reference app's domain and should not be copied.
Examples:
- Domain-specific services (SEO generators, billing integrations, vendor-specific adapters)
- Domain-specific components (product dashboards, SEO profiles)
- Domain-specific API routes (batch processing, SEO endpoints)
- Domain-specific entities beyond the base ones
- Migrations (new project will generate its own)
- LLM prompts specific to the reference app
- Locales/translations (unless generic)
- Domain-specific scripts
- `package-lock.json` (will be regenerated)
- `.next/`, `node_modules/`, `coverage/`, `log/` — build artifacts
- `.mikro-orm/` — generated cache

## Naming Analysis

Identify ALL naming patterns used in the reference project. Look for:
- npm package name (e.g., `bigcommerce-aiseo`)
- GCP project prefix (e.g., `cataseo`)
- Database name (e.g., `bigcommerce_aiseo`)
- Service display name / title
- Domain names
- Any other recurring identifier

## Exploration Strategy

1. Start with `Glob` to get the full file tree
2. Read `package.json` for project identity
3. Read `terraform/environments/*/terraform.tfvars` for infrastructure naming
4. Skim key files in each directory to understand their purpose
5. Check for hidden config files (`.github/`, `.vscode/`, etc.)

## Output Format

Output ONLY valid JSON (no markdown fences, no commentary). The JSON must have this structure:

```
{
  "reference_project": {
    "name": "package-name",
    "path": "/absolute/path",
    "description": "Brief description of what the reference project does"
  },
  "naming_patterns": {
    "npm_package": "bigcommerce-aiseo",
    "gcp_prefix": "cataseo",
    "db_name": "bigcommerce_aiseo",
    "display_name": "CatASEO",
    "other": {}
  },
  "replacements": [
    {
      "find": "bigcommerce-aiseo",
      "replace": "{{PROJECT_NAME}}",
      "description": "npm package name"
    },
    {
      "find": "cataseo",
      "replace": "{{GCP_PREFIX}}",
      "description": "GCP project/service prefix"
    },
    {
      "find": "bigcommerce_aiseo",
      "replace": "{{DB_NAME}}",
      "description": "database name (underscore format)"
    }
  ],
  "files": [
    {
      "path": "relative/path/to/file",
      "action": "copy|replace|stub|skip",
      "reason": "Brief explanation of why this classification"
    }
  ],
  "stub_guidance": {
    "relative/path/to/stub/file": "Brief description of what to keep and what to remove"
  },
  "summary": {
    "copy": 0,
    "replace": 0,
    "stub": 0,
    "skip": 0,
    "total": 0
  }
}
```

## Important Rules

1. Every file in the reference project must appear in the `files` array
2. Do NOT include `node_modules/`, `.next/`, or other gitignored build artifacts
3. For directories that are entirely one classification, you may use a glob pattern (e.g., `terraform/modules/**`)
4. The `replacements` array should capture every distinct naming pattern — the bash script will apply these as sed replacements
5. Order replacements from most specific to least specific (longer strings first) to avoid partial replacements
6. Be conservative with `copy` — if there's any chance a file contains project-specific content, classify it as `replace`
7. For `stub` files, always include an entry in `stub_guidance` explaining what to keep
