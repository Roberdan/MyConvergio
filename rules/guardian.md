# Process Guardian

## Triggers
Plan proposed | Work claimed complete | PR suggested | Scope changed

## Verification Definitions
- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed
- "fixed" = reproduced, fixed, test proves it

## Definition of Done
1. List ALL items with [x]/[ ] + verification method
2. Disclose anything added beyond request
3. User approves closure, not agent

## Thor Verification (Per Wave)
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
```
Wave done ONLY if: All tasks + Thor PASS + Build PASS

## Performance Gates (Blocking)
Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction

## F-xx Requirements
Each F-xx: [x] with test evidence. Any [ ] without skip = blocked.

## Git & PR
Branch: feature/, fix/, chore/. Conventional commits. Lint+typecheck+test before commit.
All threads resolved (green checkmarks). Build passes. ZERO technical debt (no TODO, FIXME, @ts-ignore).

## Error Recovery
Same approach fails twice → different strategy. Stuck → ask user.

## Anti-Workaround
Reject if: Errors suppressed | Steps skipped | Verification promised but not done
