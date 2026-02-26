# Phase 3: Generate CLAUDE.md

You are generating a CLAUDE.md file for a newly scaffolded project. Read the scaffolded project to understand its structure, then produce a comprehensive CLAUDE.md.

## Your Task

1. Read the scaffolded project's files using Glob and Read
2. Understand the stack, conventions, and architecture
3. Output a CLAUDE.md file (raw markdown, no code fences wrapping the whole thing)

## CLAUDE.md Structure

The file should include these sections:

### Project Overview
- Project name and brief description
- What the project does (from the provided description)

### Stack
- Framework (Next.js version, Pages Router vs App Router)
- ORM (MikroORM version, naming strategy)
- Database (PostgreSQL)
- Cache (Redis/Valkey via Memorystore)
- Infrastructure (GCP, Cloud Run, Terraform)
- Testing (Vitest)
- UI framework (if applicable)

### Project Structure
- Key directories and what they contain
- Where entities, repositories, services, pages, and components live
- Where terraform configs live

### Development Setup
- How to install dependencies
- How to set up the database
- How to run the dev server
- Required environment variables (reference .env.example if it exists)

### Database
- How to create migrations (`npm run db:migrate:create`)
- How to run migrations
- Entity conventions (bigint PKs, timestamps, UnderscoreNamingStrategy)
- Never hand-write migrations

### Testing
- How to run tests
- Test file conventions
- Test config files

### Deployment
- How to deploy (reference deploy scripts if they exist)
- Terraform environments (staging, production)

### Conventions
- Code style observations (from reading the actual code)
- Naming conventions
- Import alias paths
- Any patterns observed in the scaffolded code

## Rules

1. Only describe what actually exists in the scaffolded project — do not reference features from the reference project that were not included
2. Be concise — CLAUDE.md should be a quick reference, not exhaustive documentation
3. Use code blocks for commands and file paths
4. If a section would be empty (e.g., no deploy scripts were copied), omit it
5. Output raw markdown text — this will be written directly to CLAUDE.md
