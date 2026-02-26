# scaffold-project

Scaffold a new project from a reference codebase using Claude CLI. The script analyzes a reference project, classifies every file, and generates a working skeleton with the right names, infrastructure, and conventions.

## Prerequisites

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`)
- PostgreSQL client tools (`createdb`)
- Python 3
- `$EDITOR` set (falls back to `vi`)

## Usage

```bash
./scaffold-project.sh [options]
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--reference <path>` | `~/Projects/studio-1119/bigcommerce-aiseo` | Reference project to scaffold from |
| `--parent-dir <path>` | `~/Projects/studio-1119` | Parent directory for the new project |
| `--description-file <path>` | _(opens $EDITOR)_ | Text file with the project description |

### Examples

```bash
# Interactive — opens editor for description, then Claude for naming
./scaffold-project.sh

# Provide description from a file
./scaffold-project.sh --description-file ~/ideas/inventory-app.md

# Custom reference and parent directory
./scaffold-project.sh \
  --reference ~/Projects/my-org/reference-app \
  --parent-dir ~/Projects/my-org
```

## How It Works

### Phase 0: Validation
Checks that `claude`, `createdb`, reference directory, and parent directory all exist.

### Description Collection
Opens `$EDITOR` for you to write a multi-line project description (or reads from `--description-file`).

### Naming Discussion (Interactive)
An interactive Claude session helps you choose a project name, GCP prefix, database name, and target directory. It knows the existing portfolio and naming conventions.

### Phase 1: Inventory & Plan
Claude (Sonnet, $1 budget) explores the reference project and classifies every file as:
- **copy** — identical infrastructure files (`.gitignore`, terraform modules, vitest configs)
- **replace** — same structure, project names need find-and-replace (`package.json`, tfvars)
- **stub** — shared pattern but app-specific content; Claude generates a minimal version
- **skip** — entirely app-specific to the reference

Outputs `plan.json`. You review and can edit it before continuing.

### Phase 2a: Copy & Replace
Deterministic — bash copies verbatim files and runs find-and-replace on others. No Claude needed.

### Phase 2b: Generate Stubs
Claude (Sonnet, $2 budget) reads each reference file marked `stub` and writes a minimal working version in the target.

### Phase 3: Generate CLAUDE.md
Claude (Sonnet, $0.50 budget) reads the scaffolded project and generates a CLAUDE.md with conventions and setup instructions.

### Phase 4: Post-scaffold Init
- `git init`
- `npm install`
- Creates PostgreSQL databases (dev + test)
- Writes `.env` and `.env.test`
- Generates initial MikroORM migration
- Runs `tsc --noEmit` type check

## File Structure

```
scaffold-project/
  scaffold-project.sh          # Main entry point
  scaffold/
    phase1-inventory.md        # System prompt: analyze reference, produce plan
    phase2-scaffold.md         # System prompt: generate stubs
    phase3-claudemd.md         # System prompt: generate CLAUDE.md
```

## Cost

A typical run uses ~$3.60 in Claude API credits across the three phases.

## License

MIT
