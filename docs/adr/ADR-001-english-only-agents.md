# ADR-001: English-Only Agent Language

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

The repository had three folders:
- `.claude/agents/` (English)
- `claude-agents/` (English legacy)
- `claude-agenti/` (Italian attempt, incomplete)

The Italian folder was never completed and contained a chaotic mix of English content with Italian comments.

## Decision

All agents will be in **English only**. Delete `claude-agents/` and `claude-agenti/` legacy folders.

## Rationale

1. Claude LLMs perform better with English prompts
2. Claude responds in the user's language regardless of agent language
3. Maintaining two versions doubles maintenance effort (57 agents x 2 = 114)
4. Agent names are already in English (ali-chief-of-staff, baccio-tech-architect)
5. Industry standard for AI agent definitions

## Consequences

**Positive:**
- Single source of truth
- 50% less maintenance
- Better agent performance

**Negative:**
- Italian-only users must read English agent definitions (but Claude responds in Italian)

## Implementation

- Deleted `claude-agents/` folder
- Deleted `claude-agenti/` folder
- Deleted `scripts/translate-agents.sh`
- All 57 agents now in `.claude/agents/` only
