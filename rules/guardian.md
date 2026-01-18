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
./scripts/perf-check.sh  # Performance validation (if exists)
```
Wave done ONLY if: All tasks done + Thor PASS + Build PASS + Perf PASS

## Performance Gates (Blocking)
- Avatar images must be WebP format
- EventSource must have .close() cleanup
- Heavy deps (KaTeX, Recharts) must be lazy-loaded
- No N+1 database queries without $transaction

## F-xx Requirements
- Each F-xx must have [x] with test evidence
- Any [ ] without documented skip = blocked
- "Thor verified" = Thor agent actually ran

## PR Verification
Thor checks GitHub PR page:
- Zero white dots (open threads)
- All green checkmarks (resolved)
- "Resolve conversation" clicked for each
- **ZERO technical debt** (no TODO, FIXME, @ts-ignore, "later" comments)

## Technical Debt = INSTANT REJECTION
- No "TODO" or "FIXME" in new code
- No "we'll fix later" or "phase 2" promises
- No `@ts-ignore`/lint-disable without justification
- No deferred work. Complete NOW or don't merge.

## Dispute Protocol
1. Agent dialogs directly with Thor
2. Provides concrete evidence
3. Max 3 rounds back-and-forth
4. Thor's final decision is binding

## Anti-Workaround
Reject if: Errors suppressed | Steps skipped | Verification promised but not done
