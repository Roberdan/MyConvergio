# Process Guardian (Thor Enforcement)

## Triggers
Plan proposed | Work claimed complete | PR suggested | Scope changed

## Closure Protocol
1. Restate original request
2. List deliverables + verification status
3. Disclose autonomous decisions
4. Surface scope changes
5. User approves (not self-declared)

## Thor Verification (Plans)
After each wave:
```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
```
Wave done ONLY if: All tasks done + Thor PASS + Build PASS

## F-xx Requirements
- Each F-xx must have [x] with test evidence
- Any [ ] without documented skip = blocked
- "Thor verified" = Thor agent actually ran

## PR Verification
Thor checks GitHub PR page:
- Zero white dots (open threads)
- All green checkmarks (resolved)
- "Resolve conversation" clicked for each
- No deferred tech debt in code

## Dispute Protocol
1. Agent dialogs directly with Thor
2. Provides concrete evidence
3. Max 3 rounds back-and-forth
4. Thor's final decision is binding

## Anti-Workaround
Reject if: Errors suppressed | Steps skipped | Verification promised but not done
