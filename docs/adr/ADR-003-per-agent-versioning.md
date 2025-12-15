# ADR-003: Per-Agent Versioning

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

The repository has a `VERSION` file for system-wide versioning and a `scripts/version-manager.sh` script. Question: should we version agents individually or only at system level?

## Decision

Implement **per-agent versioning** with:
- `version:` field in each agent's YAML frontmatter
- Changelog section in each agent file
- System-wide VERSION file for overall releases

## Rationale

1. Individual agents evolve at different rates
2. Enables rollback of specific agents without affecting others
3. Supports gradual rollouts
4. Better debugging ("which version of ali-chief-of-staff was deployed?")
5. Roberto confirmed this is important

## Consequences

**Positive:**
- Granular version control
- Better traceability
- Enables A/B testing of agents

**Negative:**
- More metadata to maintain
- Need to update version-manager.sh

## Implementation

- Added `version: "1.0.0"` to all 57 agents
- Added Changelog section to each agent
- Created `scripts/bump-agent-version.sh`
- Updated `scripts/version-manager.sh` for new paths
