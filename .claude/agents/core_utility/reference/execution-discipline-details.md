---
name: execution-discipline-details
description: Reference document
type: reference
---
# Execution Discipline — Detailed Articles

Reference expansion for `EXECUTION_DISCIPLINE.md`.

## Article Coverage Matrix

| Article | Focus |
| --- | --- |
| I | Planning requirements |
| II | Execution contracts and proof |
| III | Zero-skip and anti-assumption rules |
| IV | Error recovery and retries |
| V | Parallel execution safety |
| VI | Communication standards |
| VII | Quality gates |
| VIII | Git discipline |
| IX | Delegation patterns |
| X | Continuous optimization |

## Article I — Planning

- Plan before execute for non-trivial tasks.
- Plan must include status, focus, blockers, next steps, verification.
- Tasks must be independently executable and verifiable.

## Article II — Execution Contracts

- Done claims require objective evidence.
- "Should work" is invalid without execution proof.
- Approved plans run continuously until completion or hard blocker.

## Article III — Zero-Skip

- No skipped steps, tests, or verification gates.
- Verify file existence and code state before claims.
- Never invent paths, commands, outputs, or citations.

## Article IV — Error Recovery

- Acknowledge failures immediately.
- Record root cause and corrective action.
- Do not repeat identical failed attempts.

## Article V — Parallel Execution

- Parallelize independent steps.
- Model dependencies explicitly.
- Preserve context checkpoints for longer runs.

## Article VI — Communication

- Deliver results before process narration.
- Be direct, factual, and concise.
- Report uncertainty before acting on assumptions.

## Article VII — Quality

- Treat warnings as actionable quality signals.
- Remove dead code, debug leftovers, and untracked deferred-item debt.
- Use deterministic tooling for lint/format/type checks.

## Article VIII — Git

- Follow branch naming and commit conventions.
- Use PR workflows and protect default branch integrity.
- Never bypass hooks in normal delivery flow.

## Article IX — Delegation

- Match specialist agent to task type.
- Keep validation independent from implementation.
- Use high-reasoning models only when risk justifies cost.

## Article X — Optimization

- Capture learnings after failures.
- Automate repeated workflows.
- Minimize token use while preserving operational clarity.
