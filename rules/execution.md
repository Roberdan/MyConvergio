# Execution & Quality Rules

> Core rules in CLAUDE.md. This file contains supplementary details.

## Verification Definitions
- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed if requested
- "fixed" = reproduced, fixed, test proves it
- No claim without evidence. Uncertain? Verify first.

## Definition of Done Format
Before claiming "finito":
1. List ALL originally requested items with [x] or [ ]
2. Each [x] needs verification method
3. Any [ ] = NOT done
4. Disclose anything added beyond request
5. User approves closure, not agent

## Pull Request Rules
Before PR ready:
1. ALL Copilot comments resolved (clicked "Resolve" on GitHub)
2. Zero unresolved threads (green checkmarks, not white dots)
3. Build passes: `npm run lint && npm run typecheck && npm run build`
4. No "TODO later" or "defer to next PR"

## Error Recovery
Same approach fails twice? Try different strategy. Stuck? Ask user.

## Git Conventions
Branch: feature/, fix/, chore/. PRs for review. Conventional commits.

## Quality Gates
Lint, typecheck, test before commit. No secrets in code. Fix problems when seen.

## Phase Isolation
Each workflow phase uses fresh context. Pass data via files/DB, not conversation:
- `/prompt` → writes F-xx document
- `/research` → writes research document to `.copilot-tracking/research/`
- `/planner` → writes plan to DB + file
- `/execute` → task-executor runs in isolated subagent
- Thor → always fresh context (context_isolation: true)
Never carry accumulated context between phases. Start fresh, read artifacts.
