# ADR 0011: Anti-Bypass Protocol

**Status**: Accepted
**Date**: 21 Feb 2026
**Deciders**: Roberto
**Plan**: 189

## Context

Plan 182 revealed a critical failure mode: agents bypassing the task-executor workflow and editing files directly during plan execution. This violated the entire quality control pipeline:

- No Thor validation gates (per-task or per-wave)
- No audit trail in plan database (task status, timestamps, output_data)
- No TDD enforcement (tests written after or not at all)
- No standardized task execution protocol
- Inconsistent agent behavior across different task types

The root cause was ambiguity in CLAUDE.md about when direct file editing is permissible versus when task-executor delegation is mandatory. Agents interpreted "active plan" differently, leading some to edit files directly "to save time" or "because it's a simple change."

## Decision

### Mandatory Task-Executor Delegation

**When a plan is active (`status = 'doing'`), EVERY task must go through task-executor.**

- Main agent invokes `Task(subagent_type='task-executor', task_desc='...')` for each task
- Task-executor handles: TDD workflow, Thor validation, plan-db updates, Git operations
- Main agent NEVER calls Edit/Create tools on plan-tracked files during plan execution
- Exception: Documentation-only changes NOT in the plan MAY be direct-edited (README updates, typo fixes)

### Enforcement Mechanisms

1. **CLAUDE.md Anti-Bypass Rule** (line 40-42): Explicit prohibition with Plan 182 rationale
2. **guardian.md Anti-Bypass Section** (line 17-19): Reinforcement with reference to CLAUDE.md
3. **Thor Gate 9 (ADR Compliance)**: Checks for direct edits during plan execution via Git blame + task timestamps
4. **worktree-guard.sh**: Detects active plans in current worktree, warns if no task-executor in context

### Violation Definition

A bypass violation occurs when:

- Main agent edits/creates a file tracked in plan tasks while `plan.status = 'doing'`
- Task marked `done` without Thor validation (`validated_at IS NULL`)
- Git commits made outside task-executor context during plan execution
- Task-executor skipped for "trivial" changes (no task is trivial when quality gates exist)

### Thor Enforcement

Gate 9 (Constitution & ADR Compliance) now includes bypass detection:

- Compare Git blame timestamps with task execution windows
- Flag files modified outside task-executor sessions
- Reject wave if ANY bypass violations detected
- Require evidence of task-executor invocation (logs, task status transitions)

## Consequences

### Positive

- **Quality assurance**: Every change goes through Thor gates
- **Audit trail**: Complete task execution history in plan database
- **TDD compliance**: Task-executor enforces RED-GREEN-REFACTOR
- **Consistency**: All agents follow same protocol, no exceptions
- **Debugging**: Output_data and timestamps enable post-mortem analysis
- **Trust**: No silent bypasses, all changes validated

### Negative

- **Overhead**: Task-executor invocation adds 10-30 seconds per task
- **Rigidity**: Even tiny changes require full protocol (intentional trade-off)
- **Learning curve**: Agents must understand when task-executor is mandatory
- **Token cost**: Additional context for task-executor vs. direct editing

### Migration

Existing plans mid-execution when ADR 0011 accepted:

- Finish current wave using old protocol
- Apply anti-bypass protocol starting next wave
- Run `plan-db.sh validate-wave` to detect any prior bypasses

## References

- **CLAUDE.md** (line 40-42): Anti-Bypass rule with Plan 182 rationale
- **rules/guardian.md** (line 17-19): Anti-Bypass section
- **ADR 0008**: Thor Per-Task Validation & Constitution Gate (Gate 9 enforcement)
- **agents/core_utility/task-executor.md**: Task execution protocol
- **Plan 182 Retrospective**: Original bypass incident, lessons learned

## File Impact Table

| File                                      | Purpose/Impact                                  |
|-------------------------------------------|-------------------------------------------------|
| CLAUDE.md                                 | Anti-Bypass rule (line 40-42)                   |
| rules/guardian.md                         | Anti-Bypass section (line 17-19)                |
| agents/core_utility/task-executor.md      | Mandatory protocol for plan tasks               |
| agents/core_utility/thor-*.md             | Gate 9 bypass detection logic                   |
| scripts/worktree-guard.sh                 | Active plan detection, task-executor warning    |
| scripts/plan-db.sh                        | Task status tracking, violation detection       |
| docs/adr/0008-thor-per-task-validation.md | Gate 9 constitution enforcement foundation      |
