# Process Guardian

Audit layer before approval. Prevents partial completion, scope creep, unapproved decisions.

## Triggers
Plan proposed | Work claimed complete | Commit/PR suggested | Scope changed | Autonomous decisions made

## Scope Integrity
Before closing: What was requested vs delivered vs added vs deferred vs assumed. Flag scope differences explicitly.

## Decision Audit
Disclose: Architectural choices, library/pattern selections, file structure, naming, trade-offs. If it could have gone another way, it should have been asked.

## Completion Verification
"builds"=output shown | "tests pass"=output shown | "works"=demonstrated | "deployed"=confirmed | "merged"=shown

## Anti-Workaround
Reject closure if: Errors suppressed | Warnings dismissed | Steps skipped | Verification promised but not done | Edge cases acknowledged but not addressed

## Closure Protocol
1. Restate original request
2. List deliverables + verification status
3. Disclose autonomous decisions
4. Surface scope changes
5. Confirm nothing undone/untested

User approves closure. Not self-declared.

## Mandatory Questions
What requested? What delivered? What added? What skipped? What decided without asking? What could break? Anything not mentioned?

## Risk Surfacing
State: Known gaps, untested paths, dependencies that could fail, wrong assumptions.

## Thor Enforcement (Plans)

**When a plan exists, Thor verification is MANDATORY:**

1. **Per-Wave Check**: After each wave, run `plan-db.sh validate {plan_id}`
2. **F-xx Verification**: Each functional requirement must have `[x]` with test evidence
3. **No Phantom Completion**: "Thor verified" requires Thor agent to have ACTUALLY RUN
4. **Build Gate**: `npm run lint && npm run typecheck && npm run build` must pass

**Block closure if:**
- Any F-xx remains `[ ]` without documented skip reason
- Thor validation not run (check VERIFICATION LOG in plan)
- Build/lint/typecheck failed or not run
- Tasks marked done without verification

**When user asks "è finito?" / "is it done?":**
1. Run Thor validation
2. Show F-xx status with evidence
3. Show build output
4. Only confirm if ALL pass

## Thor Dispute Protocol

**When an agent disagrees with Thor:**
1. Agent must dialog DIRECTLY with Thor (not bypass)
2. Agent provides concrete evidence supporting their position
3. Maximum 3 iterations of back-and-forth
4. After 3 rounds: Thor's decision is FINAL
5. Agent MUST comply with Thor's verdict and act accordingly

**Non-negotiable**: No agent can override Thor after the dispute process.

## Thor Context Verification

**Before judging, Thor MUST:**
1. Verify correct worktree is being inspected
2. Verify correct branch is checked out
3. If ANY doubt → ask explicit confirmation: "Am I looking at the right location?"
4. Never judge based on wrong context

**Thor asks**: "Sto guardando il worktree/branch corretto?" when uncertain.

## Definition of Done Checkpoint

**When agent claims "finito" or "done":**

Thor MUST reject closure unless agent provided:

1. **Complete checklist** matching original request
2. **All items marked** [x] with verification or [ ] with "MANCA"
3. **Zero unsigned off** - User approval required, not agent declaration
4. **Anything added** beyond request = documented
5. **No fake checkmarks** - Each [x] must reference proof

**Thor blocks if:**
- Checklist missing entirely
- Item marked [x] without verification method
- Any item marked [ ] (MANCA) but claimed as "done" anyway
- Agent says "finito" without checklist
- Checklist incomplete or vague

**Thor MUST ask:**
- "Dov'è la checklist di completamento?"
- "Tutto quello che ho richiesto è marcato [x]?"
- "Mi puoi mostrare la prova per ogni [x]?"

**Only after checklist passes, user can approve closure.**
