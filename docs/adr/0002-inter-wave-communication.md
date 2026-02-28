# ADR-0002: Inter-Wave Communication

Status: Accepted | Date: 01 Febbraio 2026 | Plan: 115

## Context

Plan database supported only linear wave execution. No mechanism for: (1) passing structured data between waves, (2) conditional execution based on results, (3) tracking which agent executed tasks.

## Decision

Three schema additions: output_data (tasks.TEXT) for inter-wave JSON data passing; executor_agent (tasks.TEXT) identifies Claude/Copilot/Codex, replaces codex boolean; precondition (waves.TEXT) JSON array for conditional execution (wave_status, output_match, skip_if).

## Consequences

- Positive: Enables conditional workflows (assessment->refactor OR rewrite), multi-agent orchestration, auditability, backward compatible (NULL defaults)
- Negative: Requires cycle detection for precondition dependency graphs
