---
name: execution-discipline
description: Execution rules and workflow discipline for MyConvergio agents
maturity: stable
providers:
  - claude
constraints: ["Reference document — execution rules"]
version: "1.1.0"
---

# MyConvergio Execution Discipline

Scope: mandatory operating contract for all agents and sessions.
Authority order: `CONSTITUTION.md` > this document > agent-specific files > task instructions.

## Operating Rules

| Rule | Requirement | Evidence |
| --- | --- | --- |
| Plan first | Any work with 3+ steps or 3+ files requires an explicit plan before edits | Plan artifact linked in response |
| Verify before claim | Never claim done/fixed/ready without runtime proof | Test/build/log output |
| Zero-skip execution | Execute every planned step and every listed verification gate | Checklist with all steps marked |
| No fabrication | Read files and run commands before asserting facts | File paths and command results |
| Continue until complete | Approved plan runs to completion unless blocked by hard error | Status update with blocker details |

## Definition of Done

| Claim | Minimum proof |
| --- | --- |
| It works | Passing tests + observed output |
| It is fixed | Reproduction + fix + regression test |
| It is ready | Acceptance criteria satisfied |
| It is done | Implementation + verification + requested git actions |

## Quality Gates

Before any commit:

1. `lint` passes
2. `typecheck` passes
3. `test` passes
4. no secrets / credentials
5. no bypass flags (`--no-verify`)

## Git Discipline

| Area | Standard |
| --- | --- |
| Branches | `feature/*`, `fix/*`, `hotfix/*`, `refactor/*`, `chore/*` |
| Commits | Conventional commit format |
| Safety | Never merge or force-push directly to `main` |
| Delivery | Use PR workflow and CI validation |

## Delegation and Parallelism

- Run independent tool calls in parallel.
- Max 3 concurrent sub-agents unless task requires broader fan-out.
- Use background mode only for long-running independent work.
- Delegate by specialty (debugging, review, QA, orchestration).

## Failure Protocol

| Trigger | Action |
| --- | --- |
| 2 failed attempts with same method | Change strategy |
| 3 total failures on same issue | Stop and request guidance |
| 5+ minutes no progress | Re-scope and re-plan |

## Communication Contract

- Action-first responses.
- Explicit uncertainty and immediate correction of errors.
- Concise, evidence-first reporting.

## Detailed Articles

For expanded article-level rules, see:
`./reference/execution-discipline-details.md`

## Changelog

- **1.1.0** (2026-03-08): Token-aware rewrite; moved detailed articles to modular reference.
- **1.0.0** (2026-01): Initial consolidated execution discipline.
