# ADR-007: Single Source of Truth (.claude/agents/)

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Three folders existed:
- `.claude/agents/` (active)
- `claude-agents/` (legacy English)
- `claude-agenti/` (incomplete Italian)

Confusion about which was authoritative.

## Decision

`.claude/agents/` is the **single source of truth**. All other folders are deleted.

## Rationale

1. `.claude/` is Claude Code's standard directory
2. Eliminates confusion about which version to use
3. Simplifies deployment script
4. Matches Claude Code documentation

## Folder Structure

```
.claude/agents/
├── leadership_strategy/    # 7 agents
├── technical_development/  # 7 agents
├── business_operations/    # 11 agents
├── design_ux/             # 3 agents
├── compliance_legal/      # 5 agents
├── specialized_experts/   # 13 agents
├── core_utility/          # 9 agents + CONSTITUTION.md
└── release_management/    # 2 agents
```

## Consequences

**Positive:**
- Clear ownership
- No version conflicts
- Standard location

**Negative:**
- Must migrate any unique content from legacy folders (done)

## Implementation

- Deleted `claude-agents/` folder
- Deleted `claude-agenti/` folder
- All 57 agents now in `.claude/agents/`
- Updated `.gitignore` to track `.claude/agents/`
