# 0039 - Post-Plan Learning Loop (Thor Gate 10)

## Context

Plans repeatedly hit the same failure patterns across sessions:
- DI parameter additions breaking all direct callers (Plan 100027: 6 tests broken)
- Shared helpers wired into subset of targets (Plan 100027: 3/6 routers missing cache invalidation)
- Pre-commit hooks catching issues agents should prevent (observability, formatting, workflow proof)

Without a structured feedback mechanism, these patterns recur because learnings stay in human memory or session context — neither persists reliably across plans.

## Decision

Add a mandatory **Post-Plan Learning Loop** (Thor Gate 10) at the end of every plan lifecycle, operating at two levels:

### Level 1: Generic (`.claude/rules/`)
Universal rules applicable to any repository, platform, or language. Examples:
- "Signature Change Impact" gate: when a function signature changes, grep ALL direct callers including tests
- "Wiring Coverage Gate": when a helper is created for N targets, verify all N import it

Constraints: max 3 new rules per plan, must include `_Why: Plan NNN — description_` annotation, merge with existing rules when possible.

### Level 2: Project-specific (repo `CLAUDE.md` / `AGENTS.md`)
Codebase-specific conventions, gotchas, and patterns. Examples:
- "In VirtualBPM, `get_logger` is mandatory — `logging.getLogger` triggers pre-commit hook"
- "ASGITransport does NOT trigger FastAPI lifespan — tests need manual create_all()"

These go in a "Project Learnings" section of the repo's `CLAUDE.md`, organized by plan/topic.

### Protocol (4 steps)
1. **Analyze**: What broke, what was manually fixed, what CI caught that agents missed
2. **Propose**: Concrete fix per finding (rule, KB entry, script fix, planner constraint)
3. **Apply**: Implement at appropriate level (generic vs project-specific)
4. **Verify**: Confirm rule would have caught the original issue

## Consequences

- `.claude/` becomes a self-improving system — each plan leaves structured knowledge
- Project repos accumulate domain-specific wisdom that survives across sessions
- Rule bloat risk mitigated by max-3-per-plan cap and merge-with-existing preference
- New contributors (human or AI) inherit accumulated learnings automatically
- `compaction-preservation.md` protects learning loop rules from being removed during optimization
