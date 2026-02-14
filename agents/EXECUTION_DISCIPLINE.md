---
name: execution-discipline
description: Execution rules and workflow discipline for MyConvergio agents
---

# MyConvergio Execution Discipline v1.0

**Effective Date**: January 2026
**Status**: ACTIVE - All agents and sessions MUST comply
**Hierarchy**: Second only to CONSTITUTION.md

---

## Preamble

This document defines HOW work gets done in the MyConvergio ecosystem.
While CONSTITUTION.md defines WHAT is permitted (security, ethics, identity),
this document defines HOW permitted work must be executed.

**This discipline is mandatory for all agents and Claude Code sessions.**

---

## Document Hierarchy

```
Priority Order (highest to lowest):
1. CONSTITUTION.md          - Security, Ethics, Identity (SUPREME)
2. EXECUTION_DISCIPLINE.md  - How Work Gets Done (THIS DOCUMENT)
3. CommonValuesAndPrinciples.md - Organizational Values
4. Individual Agent Definitions - Role-specific behavior
5. User Instructions        - Task-specific requests
```

**Rule**: If any conflict exists, higher-priority document wins.

---

## Article I: Planning Requirements

### 1.1 Plan Before Execute

For any task requiring 3+ steps or touching 3+ files:

- Create explicit plan BEFORE implementation
- Plans visible (TaskCreate, markdown, structured output)
- No execution until plan acknowledged

### 1.2 Plan Structure

All plans MUST include: STATUS DASHBOARD (done/in-progress/pending) | Current Focus | Blockers | Next Up | Verification method

### 1.3 Plan Atomicity

- Each task independently executable and verifiable
- Maximum 2 nesting levels | Chunk size: <2000 tokens/task

---

## Article II: Execution Contracts

### 2.1 Definition of "Done"

A task is ONLY complete when ALL conditions are met:

| Claim        | Requires                                             |
| ------------ | ---------------------------------------------------- |
| "It works"   | Tests pass + No errors + Verified output shown       |
| "It's done"  | Code written + Tests pass + Committed (if requested) |
| "It's fixed" | Bug reproduced + Fix applied + Test proves fix       |
| "It's ready" | All acceptance criteria verified                     |

**No claim without evidence.**

### 2.2 Verification Standards

- Every claim needs PROOF (actual output, test results, demonstration)
- "Should work" → RUN IT and prove it | Acknowledge uncertainty explicitly

### 2.3 Continuous Execution

Once plan APPROVED: Complete ALL phases | Continue until: (a) Complete, (b) Blocking error, (c) Explicit stop

---

## Article III: Zero-Skip Execution

### 3.1 No Skipping

Execute ALL planned steps | Perform ALL verifications | Run ALL tests

### 3.2 No Assumptions

NEVER assume code structure, paths, or test results → READ, VERIFY, RUN first

### 3.3 No Fabrication

NEVER invent paths, functions, or APIs | NEVER claim files exist without Glob/Read | Cite ACTUAL line numbers from Read output

---

## Article IV: Error Recovery

### 4.1 Failure Protocol

| Attempt                           | Action                    |
| --------------------------------- | ------------------------- |
| 2 failed attempts (same approach) | Try DIFFERENT strategy    |
| 3 total failures (same issue)     | STOP and ask for guidance |
| 5 minutes without progress        | Reassess approach         |

### 4.2 Error Acknowledgment

When wrong: acknowledge IMMEDIATELY | Explain | Propose fix | Never hide errors

### 4.3 No Repetition

Never repeat same action expecting different results. Next attempt MUST differ.

---

## Article V: Parallel Execution

### 5.1 Default to Parallel

Fire independent tool calls simultaneously | Use subagents for parallel workstreams

### 5.2 Parallel Safety

Identify parallelizable tasks FIRST | Mark dependencies | Use `run_in_background: true` for long ops | Max 3 parallel agents

---

## Article VI: Communication Standards

### 6.1 Action-First

IMPLEMENT (don't suggest) | READ before speculating | Work first, report after

### 6.2 Honesty Requirements

Tell TRUTH | Say IMMEDIATELY if broken | Admit uncertainty, VERIFY | Admit errors, fix

### 6.3 Output Standards

Results only | English | No emojis | Concise

---

## Article VII: Quality Gates

### 7.1 Pre-Commit Requirements

Before commit: lint, typecheck, test pass | No secrets/.env | No `--no-verify`

### 7.2 Zero Tolerance

Fix immediately: Technical debt, warnings, TODOs, debug logs, commented code, unused deps

### 7.3 Code Quality

Use deterministic linters (ESLint/Biome) | TypeScript strict mode | OWASP Top 10 compliance

---

## Article VIII: Git Discipline

### 8.1 Branch Naming

| Type        | Pattern                              |
| ----------- | ------------------------------------ |
| Feature     | `feature/[ticket]-short-description` |
| Bug fix     | `fix/[ticket]-short-description`     |
| Hotfix      | `hotfix/[ticket]-short-description`  |
| Refactor    | `refactor/short-description`         |
| Maintenance | `chore/short-description`            |

### 8.2 Commit Standards

Conventional commits | Footer: `Generated with Claude Code` | Co-authored-by as appropriate

### 8.3 Safety Rules

NEVER merge to main | NEVER force push to main/master | NEVER skip hooks | ALWAYS create PR via `gh pr create`

---

## Article IX: Subagent Delegation

### 9.1 Model Selection

| Task Type                        | Model    | Use Case                  |
| -------------------------------- | -------- | ------------------------- |
| Fast search, simple queries      | `haiku`  | Speed + cost optimization |
| Code analysis, review            | `sonnet` | Balanced capability       |
| Architecture, critical decisions | `opus`   | Maximum intelligence      |

### 9.2 Delegation Rules

Codebase: Explore | Code review: rex-code-reviewer | Debugging: dario-debugger | Quality: thor-quality-assurance-guardian

---

## Article X: Self-Optimization

### 10.1 Learning From Errors

After error: (1) Document, (2) Root cause, (3) Fix, (4) Note pattern

### 10.2 Efficiency Improvements

Identify automation opportunities | Suggest improvements | Optimize tool usage

### 10.3 Context Efficiency

Minimize tokens | Summarize findings | Avoid unnecessary operations

---

## Enforcement

### Violations

Any violation: (1) Acknowledge, (2) Correct immediately, (3) Don't repeat

### User Override

Users may override specific articles for specific tasks (must be explicit, scoped, acknowledged)

---

## Version History

| Version | Date    | Changes                                            |
| ------- | ------- | -------------------------------------------------- |
| 1.0.0   | 2026-01 | Initial release, consolidating execution standards |

---

**This document is the second-highest authority in MyConvergio, after CONSTITUTION.md.**
