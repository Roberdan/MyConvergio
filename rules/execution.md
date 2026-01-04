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

## Definition of Done (MANDATORY BEFORE CLOSURE)

**BEFORE claiming ANY task/feature/plan is "finito":**

Agent MUST provide complete checklist:

```markdown
## COMPLETION CHECKLIST

**Originalmente richiesto:**
- [x] Requirement A - Verificato: [how]
- [x] Requirement B - Verificato: [how]
- [x] Requirement C - Verificato: [how]
- [ ] Requirement D - MANCA! Non finito.

**Autonomamente aggiunto:**
- [x] Extra feature X - Aggiunto perché [why]

**Skipped/Deferred:**
- (none) oppure [reason why]

**VERDETTO: FINITO** ✓ oppure **NON FINITO - Blocco qui** ✗
```

**RULES:**
1. Agent lists EVERYTHING originally requested (from task/plan/user message)
2. Each item gets [x] with verification method or [ ] with "MANCA"
3. If ANY item = [ ], task is NOT finito
4. User must approve closure, NOT agent
5. Anything added beyond request = disclose it
6. No fake checkmarks - each [x] must have proof

## Pull Request Rules (NON-NEGOTIABLE)

**Before opening a PR:**
1. ALL Copilot comments/suggestions resolved (not just fixed, but MARKED RESOLVED)
2. Zero unresolved conversation threads
3. NO "farò dopo", NO "will improve later", NO deferred debt
4. Build passes (`npm run lint && npm run typecheck && npm run build`)
5. Tests pass (100% if new code, minimum critical paths)
6. Code review comments addressed AND marked resolved

**When agent resolves a Copilot comment:**
- Fix the code/issue
- Then MARK COMMENT AS RESOLVED (not optional)
- Don't leave comments hanging with "resolved in code"

**Forbidden on PR:**
- "I'll fix this in the next PR"
- "This can be improved later"
- "Deferred to future iteration"
- Unresolved Copilot comments
- Unresolved review threads

**PR State:**
- "Ready to merge" = ALL comments resolved, 0 unresolved
- "In progress" = has unresolved items (then DON'T claim ready)
- "Draft" = explicitly marked as not ready (better than false "ready")
