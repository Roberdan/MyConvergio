# Process Guardian (Thor Enforcement)

## Triggers
Plan proposed | Work claimed complete | PR suggested | Scope changed

## Thor Verification (Per Wave)
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
```
Wave done ONLY if: All tasks + Thor PASS + Build PASS

## Performance Gates (Blocking)
Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction

## F-xx Requirements
Each F-xx: [x] with test evidence. Any [ ] without skip = blocked. "Thor verified" = Thor actually ran.

## PR Verification
Zero white dots, all green checkmarks. ZERO technical debt (no TODO, FIXME, @ts-ignore, deferred work).

## Dispute Protocol
Agent ↔ Thor direct dialog, concrete evidence, max 3 rounds, Thor's decision binding.

## Anti-Workaround
Reject if: Errors suppressed | Steps skipped | Verification promised but not done
