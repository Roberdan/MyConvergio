# ADR-0025: Tiered Model Strategy (Sonnet/Opus/Haiku)

**Status**: Accepted — supersedes ADR-0003 (model assignment section)
**Date**: 01 March 2026
**Context**: Pro Max plan with token budget constraints; Opus overused for tasks where Sonnet/Haiku suffice.

## Decision

Replace flat "Opus everywhere" with a 3-tier model assignment:

| Tier   | Model               | When                                                                |
| ------ | ------------------- | ------------------------------------------------------------------- |
| Opus   | `claude-opus-4.6`   | Strategic planning, architecture decisions (strategic-planner only) |
| Sonnet | `claude-sonnet-4.6` | Coordination, validation (Thor), analysis, complex tasks            |
| Haiku  | `claude-haiku-4.5`  | Read-only utility: memory lookup, dashboard, status checks          |

**Haiku eligibility gate**: agent MUST have `disallowedTools: [Write, Edit]` AND task profile = pure retrieval/formatting. Any decision-making = minimum sonnet.

## Changes (Plan 287)

- 6 agents opus→sonnet: plan-post-mortem, sentinel-ecosystem-guardian, plan-business-advisor, plan-reviewer, research-report-generator, deep-repo-auditor
- 2 agents sonnet→haiku: marcus-context-memory-keeper, diana-performance-dashboard
- Thor validator row in execution-optimization.md corrected: opus→sonnet
- model-strategy.md v2.2.0: dual-mode table (claude vs copilot execution paths)
- agent-routing.md v2.2.0: Haiku Candidates section with eligibility rule

## Constraints (permanent)

- `strategic-planner` stays on opus — architectural decisions require full reasoning
- `wanda-workflow-orchestrator` stays on sonnet — complex orchestration flows
- `thor-quality-assurance-guardian` stays on sonnet — validation requires full reasoning without Opus cost

## Consequences

- Estimated 40-60% cost reduction on utility/analysis tasks
- Haiku agents cannot write/edit files by design (disallowedTools enforced)
- Per-task model in spec.yaml uses full IDs (e.g., `claude-sonnet-4.6`), not aliases
