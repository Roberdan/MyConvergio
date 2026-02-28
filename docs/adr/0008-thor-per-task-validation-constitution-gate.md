# ADR 0008: Thor Per-Task Validation & Constitution Gate

**Status**: Accepted
**Date**: 2026-02-15
**Deciders**: Roberto

## Context

Thor v3.x validated only at wave level — after all tasks in a wave completed, Thor would bulk-validate everything at once. This created two problems:

1. **Late feedback**: Issues discovered at wave validation required re-opening completed tasks, wasting tokens on re-execution
2. **No constitution enforcement**: Thor checked code quality and tests but never verified compliance with CLAUDE.md rules, coding-standards, or ADRs — the "constitution" of each repo

## Decision

### Per-Task Validation (preferred mode)

Thor validates each task immediately after the executor marks it `done`, running Gate 1-4, 8, 9 scoped to that task's files. Command: `plan-db.sh validate-task`.

### Per-Wave Validation (batch mode)

After all tasks in a wave are per-task validated, Thor runs all 9 gates at wave scope (cross-task interactions, integration, full build). Command: `plan-db.sh validate-wave`.

### Gate 9: Constitution & ADR Compliance

New mandatory gate checking:

- 9a: CLAUDE.md (global + project), coding-standards.md, guardian.md rules
- 9b: Active ADR compliance (status: Accepted), skip superseded ADRs

### ADR-Smart Mode

When a task IS updating/creating an ADR (type=`documentation`, files include `docs/adr/*.md`), Gate 9 does NOT check compliance against the ADR being modified (circular logic). Instead, it validates the ADR update itself for quality, format, and consistency with other active ADRs.

### Effort-Based Progress

Tasks carry `effort_level` (1/2/3) set by the planner. Dashboard progress bar is weighted by effort AND gated by Thor validation — only `validated_at IS NOT NULL` tasks count.

## Consequences

- Faster feedback loop: issues caught per-task, not per-wave
- Constitution is enforced automatically, not by convention
- ADR changes are validated without circular enforcement
- Progress reporting is more accurate (effort-weighted + Thor-gated)
- Slightly higher overhead per task (Thor invocation), offset by fewer late-stage failures

## Components Changed

- `thor-quality-assurance-guardian.md` v3.4.0 -> v4.0.0
- `thor-validation-gates.md` v1.0.0 -> v2.0.0
- `plan-db-validate.sh` v1.2.0 -> v1.3.0 (validate-task, validate-wave)
- `plan-db.sh` routing (2 new commands)
- `planner.md` v1.0.1 -> v1.1.0 (rules 8-10, per-task Thor)
- `execute.md` Phase 4 split into 4a/4b
- `dashboard-mini.sh` v1.1.0 -> v1.2.0 (effort, tree view, Thor badges)
- `CLAUDE.md` Thor Gate section updated
- `guardian.md` Thor section updated
