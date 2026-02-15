<!-- v2.0.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

Per-task: `plan-db.sh validate-task {task_id} {plan_id}` after each task (Gate 1-4, 8, 9) | Per-wave: `plan-db.sh validate-wave {wave_db_id}` after all tasks validated (all 9 gates + build) | Gate 9: Constitution (CLAUDE.md, coding-standards) + ADR compliance. ADR-Smart for doc tasks | All must PASS. Progress only counts Thor-validated tasks.

## Git & PR

Branch: feature/, fix/, chore/ | Conventional commits | Lint+typecheck+test before commit | All threads resolved | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore)

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done
