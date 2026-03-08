# ADR 0038: P5 Smart Agents

Status: Accepted | Date: 07 Mar 2026 | Plan: 100025

## Context
Full-context loading for every role caused unnecessary token usage and increased latency, even when tasks only needed scoped rule sets.

## Decision
Adopt role-based agent profiles with dynamic context loading and budget constraints so planner, executor, validator, and reviewer receive only required instructions.

## Consequences
- Positive: Faster dispatch with predictable context windows and lower cost.
- Negative: Misconfigured profiles can silently reduce capability for a role.

## Enforcement
- Rule: `Agent context must be loaded from role profiles, not static full bundles`
- Check: `bash tests/test-T14-01-agent-profiles.sh && bash tests/test-T14-03-context-loader-wiring.sh && bash tests/test-agent-tokens.sh`
- Ref: ADR-0025, ADR-0035
