<!-- v1.0.0 -->

# Zero Technical Debt (NON-NEGOTIABLE)

Every task started MUST be finished completely. No exceptions, no deferrals, no "next wave".

## Core Principle

"Done" means ALL requirements met, ALL verify commands pass, ALL touched files clean. Partial work = not started.

## Enforcement

| Violation | Consequence |
|---|---|
| "Out of scope" without user approval | REJECTED by Thor |
| "Deferred to next wave/PR/task" | REJECTED — finish now or don't start |
| TODO/FIXME left in code | REJECTED — resolve or remove |
| `pass` / `...` stubs | REJECTED — implement or delete |
| Suppress lint/type errors instead of fixing | REJECTED |
| "Pre-existing issue, not mine" on touched file | REJECTED — you touched it, you own it |
| Tests skipped "for speed" | REJECTED — tests are part of done |

## Executor Pre-Done Gate (MANDATORY)

Before ANY executor declares a task done, it MUST execute this sequence and show output:

```
1. Run ALL verify commands from task spec — paste output
2. If frontend files touched: type-check (tsc --noEmit with strict config)
3. If backend files touched: run related tests (pytest -k module_name)
4. git diff --name-only — confirm ONLY task-scoped files modified
5. If ANY step fails → FIX, don't declare done
```

Thor MUST re-run every verify command independently. Executor output is evidence, not proof.

## File Ownership Rule

If a task modifies ANY line in a file, the executor owns ALL issues in that file:
- Pre-existing type errors → fix them
- Pre-existing lint warnings → fix them
- Missing imports from other PRs → fix them
- Broken tests from other features → fix or flag to coordinator BEFORE declaring done

The only escape: don't touch the file. Once touched, own it completely.

## Coordinator Responsibility

The coordinator MUST NOT accept "done" from an executor without:
1. Seeing verify command output (not claims)
2. Thor validation passing
3. Zero type/lint/test errors in modified files

Accepting partial work and "fixing it later" = VIOLATION.

_Why: Plan v21/feat-full-redesign — executors left 17 TS errors, HTML in text fields, missing chart legends. Accumulated into merge nightmare requiring manual cleanup session._
