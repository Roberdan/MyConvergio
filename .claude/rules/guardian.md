# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed
- "fixed" = reproduced, fixed, test proves it
- List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence.
- Disclose anything added beyond request. User approves closure.

## Thor (Per Wave)

`plan-db.sh validate {id}` + lint + typecheck + build. All must PASS.

## Git & PR

Branch: feature/, fix/, chore/. Conventional commits. Lint+typecheck+test before commit.
All threads resolved. Build passes. ZERO debt (no TODO, FIXME, @ts-ignore).

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction
Same approach fails twice → different strategy. Stuck → ask user.
Reject if: Errors suppressed | Steps skipped | Verification promised but not done
