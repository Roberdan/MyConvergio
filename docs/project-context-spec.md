# Project Context Specification

> Standard structure for project-specific Claude configuration.

**Created**: 3 Gennaio 2026, 17:35 CET

---

## Overview

Projects use `CLAUDE.md` at repository root for project-specific context. Claude Code reads this automatically. Agents (planner, prompt, thor) reference it for project-specific rules.

---

## Design Principles

1. **Single file** - One `CLAUDE.md` per project (efficiency)
2. **Max 100 lines** - Keep concise, link to docs for details
3. **Structured sections** - Easy for agents to parse
4. **Additive only** - Project rules ADD to global rules, never override

---

## Standard CLAUDE.md Structure

```markdown
# CLAUDE.md

[One-line project description]

icon: public/logo.png   <!-- Optional: project icon for dashboard -->

## Commands

[Essential dev commands - build, test, lint, run]

## Architecture

[Key paths, patterns, tech stack - max 10 lines]

## Project Rules

[Project-specific constraints - what's different from global rules]
- Verification: [project-specific test/build commands]
- Processes: [required workflows, e.g., "all PRs need review"]
- Constraints: [e.g., "no external API calls", "WCAG AA required"]

## On-Demand Docs

[Optional: links to detailed docs agents can load if needed]
```

---

## Section Details

### Icon (OPTIONAL)
```markdown
icon: public/logo.png
```

Purpose: Project icon displayed in dashboard git panel. Path relative to project root.
Common locations: `public/logo.png`, `assets/icon.png`, `.claude/icon.png`

### Commands (REQUIRED)
```markdown
## Commands

npm run dev          # Dev server
npm run build        # Production build
npm run test         # Tests
npm run lint         # Linting
```

Purpose: Agents use these for verification. Thor runs build/test.

### Architecture (REQUIRED)
```markdown
## Architecture

**Stack**: Next.js 14 + Prisma + PostgreSQL
**Key paths**: src/lib/ (core), src/components/ (UI), prisma/ (DB)
**Patterns**: Zustand stores, Server Components, tRPC
```

Purpose: Agents understand codebase structure without exploring.

### Project Rules (REQUIRED)
```markdown
## Project Rules

**Verification**: `npm run lint && npm run typecheck && npm run build && npm test`
**Process**: All features require E2E test before merge
**Constraints**:
- WCAG 2.1 AA accessibility required
- No localStorage for user data (ADR 0015)
- Azure OpenAI primary, Ollama fallback
```

Purpose: Thor validates against these. Planner incorporates them.

### On-Demand Docs (OPTIONAL)
```markdown
## On-Demand Docs

Load with `@docs/claude/<name>.md`:
- voice-api: Voice integration details
- database: Schema and migrations
- testing: Test patterns and fixtures
```

Purpose: Detailed docs agents can read when needed (not always).

---

## Agent Integration

### How Agents Use Project Context

| Agent | Reads | Uses For |
|-------|-------|----------|
| **prompt.md** | Detects `CLAUDE.md` exists | Includes in Context section |
| **planner.md** | Reads `## Project Rules` | Adds to plan verification steps |
| **thor** | Reads `## Commands`, `## Project Rules` | Runs verification, checks constraints |

### Reading Protocol

1. Check if `./CLAUDE.md` exists in working directory
2. If exists, read first 100 lines
3. Extract relevant sections
4. Apply as additional constraints (not overrides)

---

## Conformance Command

`/conform` bootstraps a compliant CLAUDE.md:

1. Detect project type (package.json, Cargo.toml, etc.)
2. Extract commands from scripts
3. Analyze folder structure for architecture
4. Generate template with placeholders
5. User fills in project-specific rules

---

## Examples

### Minimal (30 lines)
```markdown
# CLAUDE.md

REST API for user management.

## Commands

go build ./...       # Build
go test ./...        # Tests
golangci-lint run    # Lint

## Architecture

**Stack**: Go 1.21 + Chi + PostgreSQL
**Key paths**: cmd/ (entrypoints), internal/ (business logic), pkg/ (shared)

## Project Rules

**Verification**: `go build ./... && go test ./... && golangci-lint run`
**Constraints**: No ORM, raw SQL only. All endpoints need OpenAPI spec.
```

### Full (80 lines)
See: `/path/to/your/project/CLAUDE.md`

---

## Migration for Existing Repos

Run `/conform` to:
1. Analyze existing CLAUDE.md (if any)
2. Identify missing sections
3. Generate compliant structure
4. Preserve existing content
