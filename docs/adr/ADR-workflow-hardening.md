# ADR: Workflow Hardening — Integration Completeness Quality Gates

Status: Accepted | Date: 2026-02-27

## Context

Analysis of Plans 246-262 (VirtualBPM) and Plans 220-224 (MirrorBuddy) revealed 5 systemic failure points causing ~30-40% feature loss:

| # | Failure Point | Example | Frequency |
|---|--------------|---------|-----------|
| 1 | Spec Capture: "Create X" without "Wire X" | VoiceOrb created, never used | HIGH |
| 2 | Task Decomposition: no integration tasks | CSS vars migrated, old file not removed | HIGH |
| 3 | Executor: implements letter, not spirit | Component exists, no consumer updated | MEDIUM |
| 4 | Mock Masking: tests pass, app broken | is_admin mocked=True, prod returns False | HIGH |
| 5 | Silent Failures: empty data = invisible UI | Admin with 0 studios → blank screen | ALWAYS |

Rules existed in `testing-standards.md`, `guardian.md`, `planner.agent.md` but were NOT enforced. `consumers` field in spec schema was never populated (0/5 recent specs).

## Decision

7 enforcement changes across 4 pipeline stages:

| Stage | Component | Change |
|-------|-----------|--------|
| **Spec** | `prompt.agent.md` | Wiring Inference: auto-generate "Wire X" for every "Create X" |
| **Plan** | `planner.agent.md` | Step 3.1b: BLOCK if feature/refactor task has empty consumers[] |
| **Execute** | `execute.agent.md` | Step 3.5: Consumer Audit — verify consumers import new code |
| **Validate** | `validate.agent.md` | Gate 10: Integration Reachability — orphan exports = REJECT |
| **Scripts** | `validate-css-vars.sh` | Cross-project CSS variable orphan detection |
| **Scripts** | `code-pattern-checks.sh` | `check_silent_degradation` + `check_orphan_exports` |
| **Template** | `e2e-smoke-test.spec.ts` | Reusable Playwright template with 5 validation sections |

Also: ADR 0024 covers Overlapping Wave Execution Protocol (merge-async, pr-sync, feedback injection).

## Consequences

- **Positive**: Orphan code eliminated at spec time; silent failures detected in CI; 20-60 min/wave saved
- **Negative**: Spec generation +1 step (wiring inference); planner blocks on missing consumers
- **Backward compatible**: Schema keeps consumers optional; enforcement is in planner step 3.1b
