# ADR-002: Makefile Replaces start.sh

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

The `start.sh` script was 600+ lines with bilingual UI, complex menu system, and deployed to wrong path (`~/.claude-code/agents/` instead of `~/.claude/agents/`).

## Decision

Replace `start.sh` with a simple `Makefile` providing clear commands:
- `make install` (global)
- `make install-local` (local)
- `make test`
- `make clean`
- `make update`

## Rationale

1. Makefile is standard Unix tooling, universally understood
2. Simpler, declarative syntax
3. No need for bilingual UI (ADR-001)
4. Easier to maintain and extend
5. Self-documenting with `make help`

## Consequences

**Positive:**
- ~50 lines vs 600+ lines
- Standard tooling
- Correct deployment paths

**Negative:**
- Users must have `make` installed (standard on macOS/Linux)

## Implementation

- Deleted `start.sh`
- Created `Makefile` with standard targets
- Updated README with new installation instructions
