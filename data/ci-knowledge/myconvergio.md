# MyConvergio CI Knowledge Base

Patterns from PR review and Thor validation analysis. Shell/Bash agent ecosystem for Claude Code + Copilot CLI.

## TDD Violations (most frequent Thor rejection)

- Tests MUST be written BEFORE implementation (RED → GREEN → REFACTOR)
- Coverage gate: 80% on business logic, 100% critical paths
- Tests must cover both happy path AND error paths
- Mock boundaries: NEVER mock auth functions, DB queries, or the module under test

## Silent Degradation (frequent rejection)

- NEVER `return null` on unexpected empty data
- Use `console.warn('[Component] context')` + visible feedback
- Empty data that SHOULD NOT be empty = BUG, not graceful handling
- Exception: loading states, optional features, explicit "no data" UX

## Orphan Exports (Gate 2b rejection)

- Every new file/export MUST have at least 1 consumer import
- Every new component MUST have a render site
- Grep for imports after creating new exports — zero consumers = REJECT
- Changed interfaces: ALL consumers must be updated

## Technical Debt (Gate 9 rejection)

- ZERO tolerance: no `// TODO`, `// FIXME`, `@ts-ignore` without justification
- No `any` in TypeScript without documented reason
- No empty `catch {}` blocks
- Max 250 lines per file — split if exceeds
- No "optimize later" deferred comments

## Git Hygiene

- NEVER `git merge main` into feature branch — use `git rebase origin/main`
- ALWAYS use `wave-worktree.sh create` for isolated branches
- CI Batch Fix rule: wait for FULL CI, fix ALL failures in ONE commit, push once
- Max 3 CI fix rounds — then escalate

## Shell Script Standards

- `set -euo pipefail` in every script
- Quote all variables: `"$var"` not `$var`
- Use `local` for function variables
- `trap cleanup EXIT` for temp files
- NEVER pipe to `tail`/`head`/`grep` in Bash — hooks block these

## Integration Completeness

- New API endpoint → consumer test required
- Interface change → ALL consumers audit required
- Config change → docs alignment check required
- New hook → settings.json registration required

## CI Pipeline Notes

- `code-pattern-check.sh` enforces 11 mechanical patterns (P1=block, P2=warn)
- `project-audit.sh --project-root $(pwd)` for full audit
- Thor 9-gate validation on every task completion
- Pre-commit hooks: secrets scan, bash antipattern check, worktree guard
- No build step — validation only via audit scripts
