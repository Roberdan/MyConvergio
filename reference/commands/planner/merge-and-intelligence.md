# Planner Merge and Intelligence

## Intelligence review
For plans with 3+ tasks, run:
- plan-reviewer (standard)
- plan-business-advisor
- plan-reviewer in challenger mode

Persist outputs to DB before requesting approval.

## Merge strategy (per-wave)
Planner sets `merge_mode` (`sync`, `batch`, `none`) by analyzing:
- File overlap across waves
- Domain affinity
- Risk and dependency chains
- CI cost/time
- Deploy ordering

Guidance:
- Use `batch` for same-theme intermediate waves.
- Use `sync` for API/schema/security boundaries and final closure wave.
- Use `none` only for pure docs/config without CI relevance.

## Delegation strategy
Default executor: `copilot`.
Escalate to `claude` only per model-strategy criteria:
- architecture decisions
- unknown root cause debugging
- security-critical decisions
- high-risk cross-system integration

Reference: `@planner-modules/model-strategy.md`.
