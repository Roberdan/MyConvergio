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

## Workflow Enforcement
**MANDATORY FLOW**: /prompt → /planner → Execute → Thor → User Approval

### Blocked Actions
- Execute without /prompt: "BLOCKED - run /prompt first"
- Execute without /planner: "BLOCKED - create plan with /planner first"
- Close wave without Thor: "BLOCKED - Thor validation required"
- Self-declare done: "REJECTED - user must approve"

### Verification Points
1. After /prompt: F-xx requirements extracted and confirmed
2. After /planner: Plan registered in DB, user approved
3. After Execute: Task status updated, F-xx verified
4. After Thor: Build passes, F-xx evidence documented
5. After Closure: User explicitly approved
