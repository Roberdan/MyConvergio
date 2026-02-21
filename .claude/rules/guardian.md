<!-- v2.0.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

See CLAUDE.md Thor Gate section for commands and gates.

## Anti-Bypass

See CLAUDE.md Anti-Bypass section. _Why: Plan 182._

## Git & PR

Branch: feature/, fix/, chore/ | Conventional commits | Lint+typecheck+test before commit | All threads resolved | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore)

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done
