# ADR-004: Model Tiering (Opus/Sonnet/Haiku)

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Without explicit `model:` field, all agents use the default model (often Opus), resulting in high costs. December 2025 Anthropic specs allow model selection per agent.

## Decision

Assign models based on agent complexity:
- **Opus** (2 agents): Orchestrators requiring complex reasoning
- **Sonnet** (21 agents): Strategic specialists
- **Haiku** (34 agents): Workers, quick tasks

## Rationale

1. Opus: $15/M tokens, Sonnet: $3/M, Haiku: $0.25/M
2. Most tasks don't need Opus-level reasoning
3. Haiku is 2x faster than Opus
4. Expected 85% cost reduction ($42 -> $6 per complex session)

## Model Assignment

### Opus (2 agents)
- ali-chief-of-staff (master orchestrator)
- satya-board-of-directors (strategic decisions)

### Sonnet (21 agents)
Strategic specialists requiring nuanced reasoning:
- domik-mckinsey-strategic-decision-maker
- baccio-tech-architect
- matteo-strategic-business-architect
- dan-engineering-gm
- antonio-strategy-expert
- guardian-ai-security-validator
- app-release-manager
- luca-security-expert
- thor-quality-assurance-guardian
- elena-legal-compliance-expert
- amy-cfo
- jony-creative-director
- dr-enzo-healthcare-compliance-manager
- socrates-first-principles-reasoning
- wanda-workflow-orchestrator
- xavier-coordination-patterns
- marcus-context-memory-keeper
- diana-performance-dashboard
- sophia-govaffairs
- behice-cultural-coach
- strategic-planner

### Haiku (34 agents)
Workers and quick task handlers:
- All other agents

## Consequences

**Positive:**
- 85% cost reduction
- Faster responses for simple tasks
- Appropriate capability matching

**Negative:**
- May need tuning if quality suffers

## Implementation

- Added `model:` field to all 57 agents
- Documented in CLAUDE.md
