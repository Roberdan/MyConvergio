# MyConvergio Workflow (v11)

Canonical flow aligned with global `.claude` execution policy.

## Mandatory Chain

`/prompt` → F-xx extraction → `/research` (optional) → `/planner` → DB approval → `/execute {id}` (TDD) → Thor per-task validation → Thor per-wave validation → closure (all F-xx verified) → learning loop.

Any bypass of this chain is a policy violation for multi-step work.

## Command Mapping

| Step | Claude Code | Copilot CLI |
| --- | --- | --- |
| Capture goal | `/prompt "<goal>"` | `@prompt "<goal>"` |
| Research (optional) | `/research` | `@research` |
| Create plan | `/planner` | `@planner` or `cplanner "<goal>"` |
| Execute tasks | `/execute {id}` | `@execute {id}` |
| Validate | Thor validator | `@validate {id}` |
| Close | PR + CI + merge, or validated non-code deliverable | Same |

## Phase Breakdown

### 1) Requirements

- Extract F-xx requirements from user intent.
- Persist prompt artifact in `.copilot-tracking/`.

### 2) Planning

- Generate waves and tasks mapped to F-xx.
- Require explicit review/approval before execution.

### 3) Execution (TDD)

Per task: RED → GREEN → REFACTOR.

Required checks before submission:
- Relevant tests pass
- Type/lint checks pass where applicable
- Artifacts are present and scoped

### 4) Thor Validation

Thor validates task submissions independently and blocks progression on failed gates.

### 5) Wave/Plan Closure

- Validate wave completion
- Ensure CI green before merge
- Complete plan only when all F-xx are verifiably satisfied

### 6) Learning Loop

Capture reusable lessons after closure:
- Generic rules in `.claude/rules/` (bounded, justified)
- Project-specific conventions in repo docs

## Operational Agents in Workflow

- **night-agent** (`night-maintenance`): off-hours hygiene, triage, bounded remediation.
- **sync-agent** (`claude-sync` flow): environment alignment and sync continuity.

These operational flows support the main chain; they do not replace planner/execute/validate for feature work.

## Non-Negotiable Constraints

- Max 250 lines per file
- No self-declared completion without evidence
- Batch CI fix policy
- Zero deferred technical debt at task completion

## References

- [Getting Started](./getting-started.md)
- [Infrastructure](./infrastructure.md)
- [Agent Orchestration Architecture](./AGENT_ORCHESTRATION_ARCHITECTURE.md)
