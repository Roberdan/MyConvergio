<!-- v2.0.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

See CLAUDE.md Thor Gate section for commands and gates.

## Anti-Bypass

See CLAUDE.md Anti-Bypass + Mandatory Routing sections. Plan creation = `/planner` only (Plan 225). Task execution = task-executor only (Plan 182).

## Git & PR

Branch: feature/, fix/, chore/ | Conventional commits | Lint+typecheck+test before commit | All threads resolved | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore)

## CI Batch Fix (NON-NEGOTIABLE)

Wait for FULL CI to complete before pushing fixes. Collect ALL failures. Fix ALL in one commit. Push once. Never fix-push-repeat per error. Max 3 rounds. **Pushing after fixing only 1 error while CI has more failures = REJECTED.**

## Zero Technical Debt (NON-NEGOTIABLE)

Resolve ALL issues, not just high-priority. Prioritize by severity but NEVER defer lower-priority items. Every CI error, lint warning, type error, test failure MUST be resolved. Accumulated debt = VIOLATION.

## Test Adapts to Code (NON-NEGOTIABLE)

When plan implementation changes break existing tests, **update tests to match new behavior**. NEVER revert working implementation to make old tests pass. Tests verify correctness of the NEW code, not preserve the OLD behavior. Reverting implementation to green-light stale tests = VIOLATION.

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done
