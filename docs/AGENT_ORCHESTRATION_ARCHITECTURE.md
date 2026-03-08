# Agent Orchestration Architecture (v11)

## Executive Summary

MyConvergio v11 uses explicit orchestration: agents are isolated per invocation, and coordination is managed through orchestrators and operational pipelines.

## Orchestration Model

| Layer | Responsibility | Key Agents/Flows |
| --- | --- | --- |
| Strategic orchestration | Requirement shaping, planning, synthesis | `prompt`, `planner`, `ali-chief-of-staff` |
| Execution orchestration | TDD task execution and delivery | `execute`, `task-executor`, `copilot-worker.sh` |
| Quality orchestration | Independent validation and gates | `validate`, `thor-quality-assurance-guardian` |
| Operational orchestration | Nightly maintenance and sync continuity | `night-maintenance` (night-agent), `claude-sync` (sync-agent flow) |

## Context Isolation Reality

Each agent call runs in isolated context. There is no implicit inter-agent memory transfer.

Implications:
1. Handoffs must include explicit artifacts (requirements, task IDs, file paths, acceptance criteria).
2. Validation must be independent (Thor reads files and verifies commands).
3. Operational agents must consume bounded runbooks to avoid drift.

## Night-Agent and Sync-Agent Overview

### Night-Agent (`night-maintenance`)

- Triggered by nightly guardian automation.
- Inputs: issue triage (`gh issue list`), repo state, runbook `.github/agents/night-maintenance.agent.md`.
- Outputs: bounded remediation branch/PR, nightly report JSON, DB telemetry (`nightly_jobs`).

### Sync-Agent (`claude-sync` operational profile)

- Triggered manually or by automation to align runtime assets.
- Inputs: snapshot baseline, local `.claude` state, mesh sync scripts.
- Outputs: deterministic copy set, sync branch/PR (`sync/claude-alignment-*`), updated baseline.

## Canonical Execution Chain

`/prompt` → `/research` (optional) → `/planner` → DB approval → `/execute {id}` → Thor per-task → Thor per-wave → closure + learning loop.

## Coordination Guardrails

- No direct bypass of planner flow for multi-step work.
- Task completion transitions must pass `plan-db-safe.sh` semantics before final validation.
- CI failures are fixed in batch per iteration.
- Max 250 lines per file policy applies to generated/edited artifacts.

## References

- [Workflow](./workflow.md)
- [Infrastructure](./infrastructure.md)
- [CLAUDE.md](../CLAUDE.md)
