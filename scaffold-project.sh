#!/usr/bin/env bash
set -euo pipefail

# ─── Colors & Helpers ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
die()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# Run a command in the background with a spinner and message
# Usage: run_with_spinner "message" command arg1 arg2 ...
# To redirect stdout: run_with_spinner "message" --stdout file command arg1 ...
run_with_spinner() {
  local msg="$1"; shift
  local outfile=""
  if [[ "$1" == "--stdout" ]]; then
    outfile="$2"; shift 2
  fi
  local tmpout errfile
  tmpout=$(mktemp)
  errfile=$(mktemp)
  "$@" > "$tmpout" 2>"$errfile" &
  local pid=$!
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}%s${NC} %s" "${spin:i++%${#spin}:1}" "$msg"
    sleep 0.15
  done
  printf "\r\033[K"
  if ! wait "$pid"; then
    echo -e "${RED}✗${NC} Command failed:" >&2
    [[ -s "$errfile" ]] && cat "$errfile" >&2
    [[ -s "$tmpout" ]] && cat "$tmpout" >&2
    rm -f "$tmpout" "$errfile"
    return 1
  fi
  rm -f "$errfile"
  if [[ -n "$outfile" ]]; then
    mv "$tmpout" "$outfile"
  else
    cat "$tmpout"
    rm -f "$tmpout"
  fi
}

# ─── Usage ────────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage: scaffold-project.sh [--reference <path>] [--parent-dir <path>] [--description-file <path>]

Options:
  --reference          Path to the reference project to scaffold from
                       (default: ~/Projects/studio-1119/bigcommerce-aiseo)
  --parent-dir         Parent directory for the new project
                       (default: ~/Projects/studio-1119)
  --description-file   Path to a text file with the project description
                       (if omitted, opens $EDITOR to write one)

Example:
  ./scaffold-project.sh
  ./scaffold-project.sh --description-file ~/project-idea.md
  ./scaffold-project.sh --reference ~/Projects/my-org/reference-app --parent-dir ~/Projects/my-org
EOF
  exit 1
}

# ─── Arg Parsing ──────────────────────────────────────────────────────────────

REFERENCE_DIR="$HOME/Projects/studio-1119/bigcommerce-aiseo"
PARENT_DIR="$HOME/Projects/studio-1119"
DESCRIPTION_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reference)         REFERENCE_DIR="$2"; shift 2 ;;
    --parent-dir)        PARENT_DIR="$2"; shift 2 ;;
    --description-file)  DESCRIPTION_FILE="$2"; shift 2 ;;
    -h|--help)           usage ;;
    *)                   die "Unknown option: $1" ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_DIR="$SCRIPT_DIR/scaffold"

# ─── Phase 0: Validation ─────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              Scaffold New Project                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

info "Validating prerequisites..."

# Check claude CLI
command -v claude >/dev/null 2>&1 || die "claude CLI not found. Install it first."

# Check reference dir
[[ -d "$REFERENCE_DIR" ]] || die "Reference directory not found: $REFERENCE_DIR"
[[ -f "$REFERENCE_DIR/package.json" ]] || die "Reference directory missing package.json: $REFERENCE_DIR"
[[ -d "$REFERENCE_DIR/terraform" ]] || die "Reference directory missing terraform/: $REFERENCE_DIR"

# Check parent dir
[[ -d "$PARENT_DIR" ]] || die "Parent directory not found: $PARENT_DIR"

ok "claude CLI found"
ok "Reference project: $REFERENCE_DIR"
ok "Parent directory: $PARENT_DIR"

# Check postgres
command -v createdb >/dev/null 2>&1 || die "createdb not found. Install PostgreSQL client tools."
ok "PostgreSQL tools found"

echo ""

# ─── Collect Project Description ─────────────────────────────────────────────

TMPDIR_SCAFFOLD=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SCAFFOLD"' EXIT

if [[ -n "$DESCRIPTION_FILE" ]]; then
  [[ -f "$DESCRIPTION_FILE" ]] || die "Description file not found: $DESCRIPTION_FILE"
  DESCRIPTION=$(cat "$DESCRIPTION_FILE")
else
  DESC_TMPFILE="$TMPDIR_SCAFFOLD/description.md"
  cat > "$DESC_TMPFILE" <<'DESCEOF'
# Project Description

Describe your new project here. What does it do? Who is it for?
What problem does it solve? What platforms/integrations does it need?

(Delete these instructions and write your description, then save and close.)
DESCEOF

  EDITOR="${EDITOR:-vi}"
  echo -e "${BOLD}Opening $EDITOR to write your project description...${NC}"
  $EDITOR "$DESC_TMPFILE"

  # Strip comment lines and check we got something
  DESCRIPTION=$(grep -v '^#' "$DESC_TMPFILE" | grep -v '^(Delete these' | sed '/^$/N;/^\n$/d' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [[ -z "$DESCRIPTION" ]] && die "Empty description. Aborting."
fi

ok "Description collected"
echo ""
echo -e "  ${BOLD}Description:${NC}"
echo "$DESCRIPTION" | sed 's/^/    /'
echo ""

# ─── Naming Discussion (Interactive) ─────────────────────────────────────────

echo -e "${BOLD}Naming Discussion${NC}"
info "Claude will help you choose a project name for the studio1119.ai portfolio."
echo ""

# Write description to a temp file so the system prompt doesn't break on special chars
DESC_FILE="$TMPDIR_SCAFFOLD/description.txt"
echo "$DESCRIPTION" > "$DESC_FILE"

# Build the system prompt from a heredoc to avoid quoting issues
cat > "$TMPDIR_SCAFFOLD/naming-system-prompt.md" <<SYSPROMPTEOF
You are helping name a new project in the studio1119.ai portfolio.

The user wants to build:
$(cat "$DESC_FILE")

Existing projects in the portfolio:
- trusync (npm: trusync, GCP: trusync, DB: trusync) — order sync for e-commerce
- cataSEO (npm: cataseo, GCP: cataseo, DB: cataseo) — AI-powered SEO optimization

Parent directory for new projects: $PARENT_DIR

Your job is to have a conversation with the user to decide on:
1. **Project name** (npm package name, lowercase, no spaces) — should be memorable, fit the studio1119.ai brand
2. **GCP prefix** (short, for resource naming — GCP has character limits on service names, bucket names, etc.)
3. **Database name** (typically same as project name, underscores for multi-word)
4. **Target directory** (parent dir + project name)

Naming guidelines:
- Studio 1119 projects tend to have short, catchy names (trusync, cataseo)
- GCP prefix must be short — it gets used in \${prefix}-staging, \${prefix}-prod, \${prefix}-batch-\${env}, etc.
- Name should be clear to developers about what the project does
- No conflicts with existing projects

Have a natural discussion. Propose name ideas, explain your reasoning, and ask for the user's preference. When the user has decided, use the Write tool to save the final names to this exact path:

$TMPDIR_SCAFFOLD/final-names.txt

The file must contain exactly these lines (no extra text):
PROJECT_NAME=<value>
GCP_PREFIX=<value>
DB_NAME=<value>
TARGET_DIR=<value>

After writing the file, confirm to the user that the names have been saved and they can exit.
SYSPROMPTEOF

# Run interactive Claude session — user discusses naming in their terminal
NAMES_FILE="$TMPDIR_SCAFFOLD/final-names.txt"
claude \
  --system-prompt "$(cat "$TMPDIR_SCAFFOLD/naming-system-prompt.md")" \
  --allowedTools "Write" \
  --permission-mode bypassPermissions \
  --model sonnet \
  --max-budget-usd 0.50 || true

echo ""

# Parse the final names from the file Claude wrote
if [[ -f "$NAMES_FILE" ]]; then
  PROJECT_NAME=$(grep "^PROJECT_NAME=" "$NAMES_FILE" | tail -1 | cut -d= -f2-)
  GCP_PREFIX=$(grep "^GCP_PREFIX=" "$NAMES_FILE" | tail -1 | cut -d= -f2-)
  DB_NAME=$(grep "^DB_NAME=" "$NAMES_FILE" | tail -1 | cut -d= -f2-)
  TARGET_DIR=$(grep "^TARGET_DIR=" "$NAMES_FILE" | tail -1 | cut -d= -f2-)
else
  echo ""
  echo -e "${YELLOW}Names file not found. Please enter them manually:${NC}"
  read -rp "  Project name: " PROJECT_NAME
  read -rp "  GCP prefix [$PROJECT_NAME]: " GCP_PREFIX
  [[ -z "$GCP_PREFIX" ]] && GCP_PREFIX="$PROJECT_NAME"
  DB_NAME="${PROJECT_NAME//-/_}"
  read -rp "  Database name [$DB_NAME]: " INPUT_DB_NAME
  [[ -n "$INPUT_DB_NAME" ]] && DB_NAME="$INPUT_DB_NAME"
  TARGET_DIR="$PARENT_DIR/$PROJECT_NAME"
  read -rp "  Target directory [$TARGET_DIR]: " INPUT_TARGET
  [[ -n "$INPUT_TARGET" ]] && TARGET_DIR="$INPUT_TARGET"
fi

# Validate we got names
[[ -z "$PROJECT_NAME" ]] && die "No project name determined. Aborting."
[[ -z "$GCP_PREFIX" ]] && GCP_PREFIX="$PROJECT_NAME"
[[ -z "$DB_NAME" ]] && DB_NAME="${PROJECT_NAME//-/_}"
[[ -z "$TARGET_DIR" ]] && TARGET_DIR="$PARENT_DIR/$PROJECT_NAME"

echo ""
echo -e "  ${BOLD}Final names:${NC}"
echo -e "    Project:    ${CYAN}$PROJECT_NAME${NC}"
echo -e "    GCP prefix: ${CYAN}$GCP_PREFIX${NC}"
echo -e "    Database:   ${CYAN}$DB_NAME${NC} / ${CYAN}${DB_NAME}_test${NC}"
echo -e "    Target:     ${CYAN}$TARGET_DIR${NC}"
echo ""
echo -e "${YELLOW}Press Enter to continue with these names (or Ctrl+C to abort).${NC}"
read -r

# Create target + scaffold workspace (preserve existing for incremental runs)
mkdir -p "$TARGET_DIR/.scaffold"

# Persist description for later phases
echo "$DESCRIPTION" > "$TARGET_DIR/.scaffold/description.txt"

echo ""

# ─── Phase 1: Inventory & Plan ───────────────────────────────────────────────

if [[ -f "$TARGET_DIR/.scaffold/plan.json" ]] && python3 -c "import json; json.load(open('$TARGET_DIR/.scaffold/plan.json'))" 2>/dev/null; then
  ok "Phase 1: Using existing plan from previous run"
  info "Delete $TARGET_DIR/.scaffold/plan.json to regenerate"
else
  echo -e "${BOLD}Phase 1: Analyzing reference project...${NC}"
  info "Claude will explore the reference project and classify every file."
  echo ""

  PHASE1_PROMPT_FILE="$TMPDIR_SCAFFOLD/phase1-prompt.txt"
  cat > "$PHASE1_PROMPT_FILE" <<PROMPTEOF
Analyze the reference project at: $REFERENCE_DIR

The new project is:
- Name: $PROJECT_NAME
- GCP prefix: $GCP_PREFIX
- Database name: $DB_NAME
- Description:
$(cat "$TARGET_DIR/.scaffold/description.txt")

Explore the reference project thoroughly and produce the JSON plan. Remember:
- Every file must be classified (excluding node_modules, .next, coverage, log)
- Identify all naming patterns for the replacements array
- The replacements should map reference names to the new project names:
  - npm package name -> $PROJECT_NAME
  - GCP prefix -> $GCP_PREFIX
  - database name (underscore) -> $DB_NAME
  - Display/title names -> appropriate casing of $PROJECT_NAME
- Order replacements longest-first to avoid partial matches
- Be thorough but practical — scan directories, read key files, classify intelligently
PROMPTEOF

  PHASE1_SYSTEM_PROMPT="$(cat "$SCAFFOLD_DIR/phase1-inventory.md")"
  PHASE1_PROMPT="$(cat "$PHASE1_PROMPT_FILE")"
  run_with_spinner "Analyzing project (this may take a few minutes)..." \
    --stdout "$TARGET_DIR/.scaffold/plan.json" \
    claude -p \
      --system-prompt "$PHASE1_SYSTEM_PROMPT" \
      --allowedTools "Read,Glob,Grep" \
      --permission-mode bypassPermissions \
      --model sonnet \
      --max-budget-usd 2.00 \
      "$PHASE1_PROMPT"

  # Validate we got JSON
  if ! python3 -c "import json; json.load(open('$TARGET_DIR/.scaffold/plan.json'))" 2>/dev/null; then
    warn "Plan output may contain non-JSON content. Attempting to extract JSON..."
    # Try to extract JSON from the output (Claude might add commentary)
    python3 -c "
import json, re, sys
text = open('$TARGET_DIR/.scaffold/plan.json').read()
# Find the first { and last }
start = text.find('{')
end = text.rfind('}')
if start >= 0 and end > start:
    try:
        plan = json.loads(text[start:end+1])
        json.dump(plan, open('$TARGET_DIR/.scaffold/plan.json', 'w'), indent=2)
        print('Extracted valid JSON')
    except json.JSONDecodeError as e:
        print(f'Failed to parse JSON: {e}', file=sys.stderr)
        sys.exit(1)
else:
    print('No JSON found in output', file=sys.stderr)
    sys.exit(1)
" || die "Phase 1 did not produce valid JSON. Check $TARGET_DIR/.scaffold/plan.json"
  fi

  ok "Plan generated: $TARGET_DIR/.scaffold/plan.json"
fi

# Display summary
echo ""
echo -e "${BOLD}Plan Summary:${NC}"
python3 -c "
import json
plan = json.load(open('$TARGET_DIR/.scaffold/plan.json'))
summary = plan.get('summary', {})
print(f\"  Copy:    {summary.get('copy', '?')} files\")
print(f\"  Replace: {summary.get('replace', '?')} files\")
print(f\"  Stub:    {summary.get('stub', '?')} files\")
print(f\"  Skip:    {summary.get('skip', '?')} files\")
print(f\"  Total:   {summary.get('total', '?')} files\")
print()
replacements = plan.get('replacements', [])
if replacements:
    print('  Replacements:')
    for r in replacements:
        print(f\"    {r['find']} → {r['replace']} ({r.get('description', '')})\")
"

# ─── User Review Checkpoint ──────────────────────────────────────────────────

echo ""
echo -e "${YELLOW}Review the plan at: $TARGET_DIR/.scaffold/plan.json${NC}"
echo -e "${YELLOW}Edit it if needed, then press Enter to continue (or Ctrl+C to abort).${NC}"
read -r

# ─── Phase 2a: Copy & Replace (deterministic) ────────────────────────────────

echo ""
echo -e "${BOLD}Phase 2a: Copying and replacing files...${NC}"

# Read plan and execute copy/replace operations
python3 <<PYEOF
import json, os, shutil, re

plan = json.load(open('$TARGET_DIR/.scaffold/plan.json'))
reference = '$REFERENCE_DIR'
target = '$TARGET_DIR'

replacements = plan.get('replacements', [])
files = plan.get('files', [])

copy_count = 0
replace_count = 0
errors = []

for entry in files:
    path = entry['path']
    action = entry['action']

    if action not in ('copy', 'replace'):
        continue

    # Handle glob patterns
    if '**' in path or '*' in path:
        import glob
        matched = glob.glob(os.path.join(reference, path), recursive=True)
        matched = [os.path.relpath(m, reference) for m in matched if os.path.isfile(m)]
    else:
        matched = [path]

    for rel_path in matched:
        src = os.path.join(reference, rel_path)
        dst = os.path.join(target, rel_path)

        if not os.path.isfile(src):
            continue

        os.makedirs(os.path.dirname(dst), exist_ok=True)

        try:
            if action == 'copy':
                shutil.copy2(src, dst)
                copy_count += 1
            elif action == 'replace':
                try:
                    with open(src, 'r', encoding='utf-8') as f:
                        content = f.read()
                    for r in replacements:
                        content = content.replace(r['find'], r['replace'])
                    with open(dst, 'w', encoding='utf-8') as f:
                        f.write(content)
                    replace_count += 1
                except UnicodeDecodeError:
                    # Binary file — just copy
                    shutil.copy2(src, dst)
                    copy_count += 1
        except Exception as e:
            errors.append(f"{rel_path}: {e}")

print(f"  Copied: {copy_count} files")
print(f"  Replaced: {replace_count} files")
if errors:
    print(f"  Errors: {len(errors)}")
    for e in errors:
        print(f"    - {e}")
PYEOF

ok "Copy & replace complete"

# ─── Phase 2b: Generate Stubs (Claude) ───────────────────────────────────────

echo ""
echo -e "${BOLD}Phase 2b: Generating stub files...${NC}"
info "Claude will read reference patterns and generate minimal working stubs."
echo ""

# Extract stub files, filtering out ones that already exist in the target
STUB_INFO=$(python3 -c "
import json, os
plan = json.load(open('$TARGET_DIR/.scaffold/plan.json'))
stubs = [f for f in plan.get('files', []) if f['action'] == 'stub']
guidance = plan.get('stub_guidance', {})
target = '$TARGET_DIR'
pending = []
skipped = 0
for s in stubs:
    path = s['path']
    if os.path.exists(os.path.join(target, path)):
        skipped += 1
        continue
    guide = guidance.get(path, s.get('reason', 'Generate minimal working version'))
    pending.append(f'  - {path}: {guide}')
if skipped:
    print(f'(Skipping {skipped} stubs that already exist)')
if pending:
    print('Stub files to generate:')
    print('\n'.join(pending))
else:
    print('ALL_STUBS_DONE')
")

if [[ "$STUB_INFO" == *"ALL_STUBS_DONE"* ]]; then
  ok "Phase 2b: All stubs already generated from previous run"
else
  PHASE2_PROMPT_FILE="$TMPDIR_SCAFFOLD/phase2-prompt.txt"
  cat > "$PHASE2_PROMPT_FILE" <<PROMPTEOF
Generate stub files for the new project.

Reference project: $REFERENCE_DIR
Target project: $TARGET_DIR
Project name: $PROJECT_NAME
Description:
$(cat "$TARGET_DIR/.scaffold/description.txt")

$STUB_INFO

For each stub file:
1. Read the reference version at $REFERENCE_DIR/<path>
2. Understand the pattern and structure
3. Write a minimal working version at $TARGET_DIR/<path>
4. Ensure it compiles (valid TypeScript, correct imports)

Remember: the target already has copy/replace files in place. Your stubs should be consistent with them.
PROMPTEOF

  PHASE2_SYSTEM_PROMPT="$(cat "$SCAFFOLD_DIR/phase2-scaffold.md")"
  PHASE2_PROMPT="$(cat "$PHASE2_PROMPT_FILE")"
  if run_with_spinner "Generating stub files (this may take a few minutes)..." \
    claude -p \
      --system-prompt "$PHASE2_SYSTEM_PROMPT" \
      --allowedTools "Read,Write,Glob" \
      --permission-mode bypassPermissions \
      --model sonnet \
      --max-budget-usd 5.00 \
      "$PHASE2_PROMPT"; then
    ok "Stub generation complete"
  else
    warn "Stub generation did not fully complete (may have hit budget limit)"
    info "Re-run the script to generate remaining stubs incrementally"
  fi
fi

# ─── Phase 3: Generate CLAUDE.md ─────────────────────────────────────────────

echo ""

if [[ -f "$TARGET_DIR/CLAUDE.md" ]] && [[ -s "$TARGET_DIR/CLAUDE.md" ]]; then
  ok "Phase 3: CLAUDE.md already exists from previous run"
  info "Delete $TARGET_DIR/CLAUDE.md to regenerate"
else
  echo -e "${BOLD}Phase 3: Generating CLAUDE.md...${NC}"
  echo ""

  PHASE3_PROMPT_FILE="$TMPDIR_SCAFFOLD/phase3-prompt.txt"
  cat > "$PHASE3_PROMPT_FILE" <<PROMPTEOF
Generate a CLAUDE.md for the project at: $TARGET_DIR

Project name: $PROJECT_NAME
Description:
$(cat "$TARGET_DIR/.scaffold/description.txt")

Read the scaffolded project files and generate the CLAUDE.md content. Output raw markdown only — no wrapping code fences.
PROMPTEOF

  PHASE3_SYSTEM_PROMPT="$(cat "$SCAFFOLD_DIR/phase3-claudemd.md")"
  PHASE3_PROMPT="$(cat "$PHASE3_PROMPT_FILE")"
  run_with_spinner "Generating CLAUDE.md..." \
    --stdout "$TARGET_DIR/CLAUDE.md" \
    claude -p \
      --system-prompt "$PHASE3_SYSTEM_PROMPT" \
      --allowedTools "Read,Glob" \
      --permission-mode bypassPermissions \
      --model sonnet \
      --max-budget-usd 1.00 \
      "$PHASE3_PROMPT"

  ok "CLAUDE.md generated"
fi

# ─── Phase 4: Post-scaffold Init ─────────────────────────────────────────────

echo ""
echo -e "${BOLD}Phase 4: Initializing project...${NC}"

cd "$TARGET_DIR"

# Git init
if [[ -d ".git" ]]; then
  ok "Git repository already initialized"
else
  git init -q
  ok "Git repository initialized"
fi

# npm install
if [[ -d "node_modules" ]]; then
  ok "Dependencies already installed"
elif [[ -f "package.json" ]]; then
  info "Running npm install..."
  npm install --loglevel=error 2>&1 | tail -5
  ok "Dependencies installed"
else
  warn "No package.json found — skipping npm install"
fi

# Create PostgreSQL databases
info "Creating PostgreSQL databases..."
if createdb "$DB_NAME" 2>/dev/null; then
  ok "Created database: $DB_NAME"
else
  warn "Database $DB_NAME already exists (or creation failed)"
fi
if createdb "${DB_NAME}_test" 2>/dev/null; then
  ok "Created database: ${DB_NAME}_test"
else
  warn "Database ${DB_NAME}_test already exists (or creation failed)"
fi

# Write .env and .env.test for local development
echo "DATABASE_URL=postgresql://localhost:5432/$DB_NAME" > .env
ok "Created .env with DATABASE_URL"
echo "DATABASE_URL=postgresql://localhost:5432/${DB_NAME}_test" > .env.test
ok "Created .env.test with DATABASE_URL"

# Generate initial migration
if [[ -f "mikro-orm.config.ts" ]] && command -v npx >/dev/null 2>&1; then
  info "Generating initial migration..."
  GENERATE_METADATA=1 npx mikro-orm migration:create --initial 2>&1 | tail -3
  ok "Initial migration created"
fi

# Type check
if [[ -f "tsconfig.json" ]]; then
  info "Running type check..."
  if npx tsc --noEmit 2>&1 | tail -10; then
    ok "Type check passed"
  else
    warn "Type check had errors — review and fix manually"
  fi
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    ${GREEN}Scaffold Complete!${NC}${BOLD}                     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Project: ${CYAN}$TARGET_DIR${NC}"
echo -e "  Plan:    ${CYAN}$TARGET_DIR/.scaffold/plan.json${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. cd $TARGET_DIR"
echo -e "    2. Review CLAUDE.md"
echo -e "    3. Set up .env.local with your credentials"
echo -e "    4. npm run dev"
echo -e "    5. Start building!"
echo ""
