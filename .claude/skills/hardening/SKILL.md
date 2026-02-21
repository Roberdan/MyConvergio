---
name: hardening
description: Audit and harden any repository with standardized quality gates, hooks, and scripts
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Edit
context: fork
user-invocable: true
version: "1.1.0"
---

# Repo Hardening Skill

Standardize quality gates across any repository. Detects project type, audits existing infrastructure, reports gaps, and applies hardening templates.

## When to Use

- Setting up a new repository
- Auditing an existing project for quality gaps
- Bringing a project to production-readiness standards
- Periodic maintenance (quarterly hardening review)

## Execution Steps

### Step 0: Quick Check (optional)

For a fast pass/fail assessment without applying changes:

```bash
~/.claude/scripts/hardening-check.sh --project-root .
```

Returns JSON with `status: "pass"|"gaps_found"`, `score`, and `gaps[]` with severity levels. Used by planner (step 1.7) to decide if Wave 0 hardening is needed.

### Step 1: Detect Project Type

Read the project root and classify:

| Signal                                | Type       | Look For                                    |
| ------------------------------------- | ---------- | ------------------------------------------- |
| `package.json`                        | Node/JS/TS | npm scripts, vitest/jest/playwright, eslint |
| `requirements.txt` / `pyproject.toml` | Python     | pytest, ruff/flake8/black, mypy             |
| `Cargo.toml`                          | Rust       | cargo test, clippy                          |
| `go.mod`                              | Go         | go test, golangci-lint                      |
| Mixed (multiple)                      | Hybrid     | Both frontend and backend                   |

Note the project root, source directories, and test framework.

### Step 2: Audit Existing Infrastructure

Check each category and report status:

**Git Hooks** (`.husky/`, `.githooks/`, `.pre-commit-config.yaml`):

- [ ] Pre-commit hook exists and has >1 check
- [ ] Pre-push hook exists with quality gates
- [ ] Commit message convention enforced (commitlint, etc.)

**Secrets Scanning**:

- [ ] Pre-commit secrets scan (staged files)
- [ ] detect-secrets baseline or equivalent

**Testing**:

- [ ] Smart test on commit (only staged file tests)
- [ ] Full test suite on push
- [ ] Coverage thresholds configured

**Debt Enforcement**:

- [ ] TODO/FIXME limits enforced
- [ ] Type suppression limits (@ts-ignore, # noqa)
- [ ] Large file detection

**Environment Variables**:

- [ ] `.env.example` exists with all vars documented
- [ ] Env-var audit script validates documentation

**PR Template**:

- [ ] Structured template with verification evidence section
- [ ] Workaround declaration section
- [ ] Explicit scope boundaries (changes NOT made)

**CI/CD**:

- [ ] Lint step
- [ ] Type check step
- [ ] Test step with coverage threshold
- [ ] Build step
- [ ] Security audit (npm audit / pip-audit)

**ADR Structure** (token-optimized for agent workflows):

- [ ] `docs/adr/` directory exists
- [ ] ADR index file exists (`docs/adr/INDEX.md`)
- [ ] ADRs follow compact format (Status/Date header, Context, Decision, Consequences, Files Changed, References)
- [ ] No ADR exceeds 200 lines (compact = agent-friendly)

### Step 3: Generate Gap Report

For each unchecked item, report:

- **Severity**: critical (security/data loss risk), warning (quality risk), info (improvement)
- **Template available**: yes/no (reference from `~/.claude/templates/repo-hardening/`)
- **Effort**: quick (copy template), medium (adapt template), custom (write from scratch)

Format as a markdown table.

### Step 4: Apply Templates

For each gap with a template available, adapt and apply:

1. Read the template from `~/.claude/templates/repo-hardening/`
2. Identify `# ADAPT:` comments in the template
3. Replace with project-specific values (paths, commands, thresholds)
4. Write to the project directory
5. Make scripts executable (`chmod +x`)

**Template locations**:

| Template        | Source                                                               |
| --------------- | -------------------------------------------------------------------- |
| Pre-commit hook | `~/.claude/templates/repo-hardening/hooks/pre-commit.sh`             |
| Pre-push hook   | `~/.claude/templates/repo-hardening/hooks/pre-push.sh`               |
| Smart test      | `~/.claude/templates/repo-hardening/scripts/smart-test.sh`           |
| Debt check      | `~/.claude/templates/repo-hardening/scripts/debt-check.sh`           |
| Env-var audit   | `~/.claude/templates/repo-hardening/scripts/env-var-audit.sh`        |
| Secrets scan    | `~/.claude/templates/repo-hardening/scripts/secrets-scan.sh`         |
| PR template     | `~/.claude/templates/repo-hardening/github/pull_request_template.md` |
| ADR template    | `~/.claude/templates/repo-hardening/docs/adr-template.md`            |
| ADR index       | `~/.claude/templates/repo-hardening/docs/adr-index-template.md`      |

**Adaptation rules by project type**:

| Project Type | SRC_DIR     | Test Runner                   | Env Pattern              | Lint     |
| ------------ | ----------- | ----------------------------- | ------------------------ | -------- |
| Node/Vite    | `src`       | `npx vitest related`          | `import.meta.env.VITE_*` | `eslint` |
| Node/CJS     | `src`       | `npx jest --findRelatedTests` | `process.env.*`          | `eslint` |
| Python       | `app`/`src` | `pytest --co -q`              | `os.environ`/`os.getenv` | `ruff`   |
| Hybrid       | Both dirs   | Both runners                  | Both patterns            | Both     |

### Step 5: Verify

After applying, run a quick verification:

1. `git status` — show new/modified files
2. Run each new script with `--help` or dry-run to confirm it works
3. Stage a test file and run `bash .husky/pre-commit` manually
4. Report what was applied and what remains manual

## Output Format

```markdown
# Hardening Report: {project_name}

## Project Type: {type}

## Audit Date: {date}

### Status: {X}/{total} checks passing

| Category   | Status                  | Action Taken |
| ---------- | ----------------------- | ------------ |
| Pre-commit | applied/existed/missing | ...          |
| Pre-push   | applied/existed/missing | ...          |
| ...        | ...                     | ...          |

### Applied

- {list of files created/modified}

### Manual Actions Required

- {list of items that need human decision}
```
