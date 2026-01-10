# Execution & Quality Rules

## Behavior
- **Verify first**: Read files before answering. No fabrication of paths/APIs/functions.
- **Act, don't suggest**: Implement changes directly unless explicitly asked for suggestions.
- **Minimum complexity**: Only requested changes. No over-engineering, no extra features.
- **Parallel tools**: Independent tool calls in parallel. Sequential only if dependent.

## Planning
- Plan non-trivial tasks visibly (todo/markdown)
- Steps must be independently executable and verifiable
- Plan started = plan finished. No skipping tasks.

## Verification
- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed if requested
- "fixed" = reproduced, fixed, test proves it
- No claim without evidence. Uncertain? Verify first.

## Definition of Done
Before claiming "finito":
1. List ALL originally requested items with [x] or [ ]
2. Each [x] needs verification method
3. Any [ ] = NOT done
4. Disclose anything added beyond request
5. User approves closure, not agent

## MANDATORY PRE-CLOSURE CHECKLIST (NON-NEGOTIABLE)

**BEFORE saying "done/completato/finito", MUST execute these commands:**

```bash
# 1. Git status - MUST be clean or all changes staged
git status --short

# 2. Verify created files exist with line counts
ls -la {created_files} && wc -l {created_files}

# 3. Commit if uncommitted changes exist
git add -A && git commit -m "..."

# 4. Show last commits as proof
git log --oneline -3
```

**VIOLATIONS:**
- Claiming "done" with uncommitted changes = FAILURE
- Claiming file exists without `ls` verification = FAILURE
- Claiming line count without `wc -l` verification = FAILURE
- Updating docs after claiming done = FAILURE (update BEFORE)

**SELF-CHECK QUESTIONS (answer before claiming done):**
1. Did I run `git status`? Is it clean?
2. Did I verify every created/modified file exists?
3. Did I commit with descriptive message?
4. Did I update relevant documentation?
5. Can I show evidence for every claim?

## Pull Request Rules
Before PR ready:
1. ALL Copilot comments resolved (clicked "Resolve" on GitHub)
2. Zero unresolved threads (green checkmarks, not white dots)
3. Build passes: `npm run lint && npm run typecheck && npm run build`
4. No "TODO later" or "defer to next PR"

## Error Recovery
Same approach fails twice? Try different strategy. Stuck? Ask user.

## Git
Branch: feature/, fix/, chore/. PRs for review. Conventional commits.

## Writing Code & Docs
- **Max 250 lines/file** - Check BEFORE writing. Split if exceeds.
- New file? Verify it won't exceed limit.
- Editing file? Check current + new lines won't exceed.
- Violation? Split into modules first, then write.

## Quality
Lint, typecheck, test before commit. No secrets in code. Fix problems when seen.
