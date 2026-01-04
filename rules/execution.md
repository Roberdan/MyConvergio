# Execution Principles

## Planning
Plan non-trivial tasks. Visible plan (todo/markdown). Flat plans. Steps independently executable and verifiable.

## Verification
"works"=tested, no errors, output shown | "done"=written, tests pass, committed if requested | "fixed"=reproduced, fixed, test proves it
No claim without evidence. Uncertain? Verify first.

## Honesty
Truth over sounding good. Failures: say immediately. Unsure: say so, then verify. Wrong: admit and fix.

## Anti-Fabrication
Never invent paths/functions/APIs—read first. Never assume structure—verify. Never quote docs from memory—fetch. Never claim file exists without checking.

## Error Recovery
Same approach fails twice? Different strategy. Stuck? Stop and ask. Never repeat expecting different results.

## Quality
Lint, typecheck, test before commit. No secrets in commits. No skipping hooks. Fix problems when seen.

## Git
Branch names: feature/, fix/, chore/. Never merge to main directly. PRs for review. Conventional commits.

## Parallel Work
Independent calls simultaneously. Subagents for parallel workstreams. Identify parallelizable during planning.

## Full Plan Execution (NON-NEGOTIABLE)

**If a plan is requested to be executed fully:**
1. Execute 100% of tasks - no exceptions
2. No unilateral "skip" of any task
3. No scope negotiation mid-execution
4. Plan incomplete = Plan FAILED

**Forbidden phrases:**
- "I'll skip this for now"
- "This can be done later"
- "Not critical, moving on"
- "Out of scope" (if it was IN the plan)

## No "Non-Blocking Missing"

**If something is missing, it IS blocking.**

Forbidden:
- "Missing but non-blocking"
- "Not implemented but doesn't affect..."
- "We can live without..."

Reality:
- Missing = Blocking
- Incomplete = Failed
- Partial = Not done

**Agent says "missing"? → Task is BLOCKED until resolved.**
