# Execution & Quality Rules

## Verification Definitions
- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed
- "fixed" = reproduced, fixed, test proves it

## Definition of Done
1. List ALL items with [x] or [ ] + verification method
2. Disclose anything added beyond request
3. User approves closure, not agent

## PR Rules
All threads resolved (green checkmarks). Build passes. No deferred work.

## Git
Branch: feature/, fix/, chore/. Conventional commits. Lint+typecheck+test before commit.

## Error Recovery
Same approach fails twice → different strategy. Stuck → ask user.

## Phase Isolation
Each phase uses fresh context. Data via files/DB, not conversation:
`/prompt` → F-xx file | `/research` → research file | `/planner` → DB + file | `/execute` → isolated subagent | Thor → always fresh
