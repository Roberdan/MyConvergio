<!-- v2.0.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

Per-task: `plan-db.sh validate-task {task_id} {plan_id}` after each task (Gate 1-4, 8, 9) | Per-wave: `plan-db.sh validate-wave {wave_db_id}` after all tasks validated (all 9 gates + build) | Gate 9: Constitution (CLAUDE.md, coding-standards) + ADR compliance. ADR-Smart for doc tasks | All must PASS. Progress only counts Thor-validated tasks.

## Anti-Bypass Rule (NON-NEGOTIABLE)

**NEVER execute plan tasks by editing files directly.** EVERY task in an active plan MUST go through `Task(subagent_type='task-executor')`. No exceptions for "simple" tasks, config changes, or documentation. The task-executor has built-in Thor (Phase 4.9) — bypassing it = bypassing Thor = VIOLATION.

**Prohibited pattern**: Read file → Edit file → mark task done in DB → skip Thor. This is exactly what manual execution does.

**Required pattern**: For EACH task: `plan-db.sh update-task $ID in_progress` → `Task(subagent_type='task-executor', ...)` → task-executor runs Thor internally → `plan-db.sh validate-task` → next task.

**If you catch yourself editing files while a plan is active**: STOP. Route through task-executor. If task-executor is overkill for 1-line change, the task was wrongly sized — split or absorb it.

## Git & PR

Branch: feature/, fix/, chore/ | Conventional commits | Lint+typecheck+test before commit | All threads resolved | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore)

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done
