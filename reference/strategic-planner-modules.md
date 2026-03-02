# Strategic Planner - Detailed Modules

> On-demand reference. Not auto-loaded. Consult when detailed planning needed.

## Plan Document Structure Template

```markdown
# [Project Name] Execution Plan

**Date**: [YYYY-MM-DD]
**Last Update**: [YYYY-MM-DD HH:MM TZ] ← USE `date +"%Y-%m-%d %H:%M %Z"` for accuracy!
**Version**: [X.Y.Z]
**Objective**: [Clear goal statement]
**Analyzed by**: [Agent/Team]

---

## 📊 PROGRESS DASHBOARD

**Overall**: ████████░░░░░░░░░░░░ **X%** (X/Y tasks)
**Elapsed**: Xh Xm | **Started**: [HH:MM TZ] or [MM-DD HH:MM TZ]

| Wave | Tasks | Progress        | Started | Ended | Time  | Status |
| :--: | :---: | --------------- | :-----: | :---: | :---: | :----: |
|  W0  |  X/Y  | ██████████ 100% |  10:00  | 10:45 |  45m  |   ✅   |
|  W1  |  X/Y  | ████████░░ 80%  |  10:45  | 11:50 | 1h05m |   ✅   |
|  W2  |  X/Y  | ███░░░░░░░ 35%  |  11:50  |   -   | 45m+  |   🔄   |
|  W3  |  X/Y  | ░░░░░░░░░░ 0%   |    -    |   -   |   -   |   ⏳   |

> **Time format**: Same day = `HH:MM`, different day = `MM-DD HH:MM`
> **Progress bar**: Each █ = 10%, use `█` for complete, `░` for remaining

| Current Wave | Blockers | Active | Next Up |
| :----------: | -------- | :----: | ------- |
|    Wave X    | None     | C2, C3 | T-XX    |

---

## OPERATING INSTRUCTIONS

> This plan MUST be updated at every completed step.
> After each task:
>
> 1. Update status (`⬜` → `✅✅`)
> 2. Add completion timestamp with DATE AND TIME
> 3. Save the file
> 4. ALWAYS use shell for accurate time: `date +"%Y-%m-%d %H:%M %Z"`

---

## PROGRESS STATUS

**Last update**: [YYYY-MM-DD HH:MM TZ]
**Current wave**: [WAVE X]
**Total progress**: [X/Y tasks (Z%)]

### WAVE 0 - Prerequisites

| Status | ID  | Task   | Assignee     | Est | Started | Ended | Actual |
| :----: | --- | ------ | ------------ | :-: | ------- | ----- | :----: |
|   ⬜   | W0A | [Task] | **CLAUDE 2** | 1h  |         |       |        |

**Wave 0 Status**: X/Y completed

---

### WAVE FINAL - Documentation & Deployment (MANDATORY)

| Status | ID    | Task                                          | Assignee     | Est | Started | Ended | Actual |
| :----: | ----- | --------------------------------------------- | ------------ | :-: | ------- | ----- | :----: |
|   ⬜   | WF-01 | Update CHANGELOG.md                           | **CLAUDE 1** | 15m |         |       |        |
|   ⬜   | WF-02 | Create/update ADRs for architecture decisions | **CLAUDE 1** | 30m |         |       |        |
|   ⬜   | WF-03 | Update README if new features                 | **CLAUDE 1** | 20m |         |       |        |
|   ⬜   | WF-04 | Update API docs if endpoints changed          | **CLAUDE 1** | 20m |         |       |        |
|   ⬜   | WF-05 | Final lint/typecheck/build verification       | **CLAUDE 1** | 10m |         |       |        |
|   ⬜   | WF-06 | Create release commit and tag                 | **CLAUDE 1** | 10m |         |       |        |

> ⚠️ **WAVE FINAL is NOT optional** - Skip = incomplete delivery

**Wave FINAL Status**: X/Y completed

---

## 📋 ISSUE TRACKING

| Issue | Title         |   Tasks    | Progress       | Owner | Started | Ended | Time |
| :---: | ------------- | :--------: | -------------- | :---: | ------- | ----- | :--: |
|  #XX  | [Issue title] | T-01, T-02 | ████░░░░░░ 40% |  C2   | 10:00   | -     | 1h+  |

> **Legend**: C2=Claude 2, C3=Claude 3, C4=Claude 4

---

## 📊 TIME STATISTICS

### Estimated vs Actual

| Phase     | Estimated | Actual | Variance |
| --------- | :-------: | :----: | :------: |
| Wave 0    |    Xh     |   Yh   |   +Z%    |
| Wave 1    |    Xh     |   -    |    -     |
| **TOTAL** |  **Xh**   | **Yh** | **+Z%**  |

### Per-Claude Performance

| Claude   | Tasks | Time Spent | Avg/Task |
| -------- | :---: | :--------: | :------: |
| CLAUDE 2 |   X   |     Yh     |    Zm    |
| CLAUDE 3 |   X   |     Yh     |    Zm    |
| CLAUDE 4 |   X   |     Yh     |    Zm    |

---

## SUMMARY BY WAVE

|   Wave    | Description   | Tasks | Done  | Status |
| :-------: | ------------- | :---: | :---: | :----: |
|    W0     | Prerequisites |   X   |   Y   |   Z%   |
|    ...    | ...           |  ...  |  ...  |  ...   |
| **TOTAL** |               | **X** | **Y** | **Z%** |

---

## DEPENDENCY GRAPH

[ASCII diagram showing wave dependencies]

---

## ADRs (Architecture Decision Records)

[Document all significant decisions with rationale]

---

## COMMIT HISTORY

| Date | Commit | Wave | Description |
| ---- | ------ | :--: | ----------- |

---

## RISK REGISTER

| ID  | Risk | Impact | Probability | Mitigation |
| --- | ---- | :----: | :---------: | ---------- |
```

## Non-Negotiable Rules Section

```markdown
## 🚨 NON-NEGOTIABLE CODING RULES

### Zero Tolerance

Zero tolerance for: bullshit, technical debt, errors, warnings, forgotten TODOs, debug console.logs, commented code, temporary files, unused dependencies. If you see something wrong, FIX IT NOW.

### Mandatory Verification for EVERY Task

\`\`\`bash
npm run lint # MUST be 0 errors, 0 warnings
npm run typecheck # MUST compile without errors
npm run build # MUST build successfully
\`\`\`

### Testing Rules

- If tests exist → they MUST pass
- If you add functionality → add tests
- Use Explore agent to find existing test patterns

### Honest Behavior

- "It works" = tests pass + no errors + verified output shown
- "It's done" = code written + tests pass + committed (if requested)
- "It's fixed" = bug reproduced + fix applied + test proves fix works
- NO CLAIM WITHOUT EVIDENCE

### Plan Updates (MANDATORY after each task)

1. Update Status from ⬜ to ✅
2. Fill in timestamps: Started, Ended, Actual time
3. ALWAYS use shell for accurate time: \`date +"%Y-%m-%d %H:%M %Z"\`
4. Update PROGRESS DASHBOARD percentages
5. Update ISSUE TRACKING progress bars

### GitHub Issue Closure

- Link tasks to issues: T-01 → #XX
- When all tasks for an issue are ✅, issue CAN be closed
- Add issue number in commit message: \`fix: complete T-01 for #XX\`

### Documentation Rules (MANDATORY)

- Every plan MUST include documentation tasks in WAVE FINAL
- If architecture changes → create/update ADR
- If API changes → update API docs
- If new feature → update README/user docs
- If behavior changes → update CHANGELOG
- Documentation debt = technical debt = ZERO TOLERANCE

### Engineering Fundamentals (MANDATORY)

- ALWAYS apply Microsoft ISE Engineering Fundamentals: https://microsoft.github.io/code-with-engineering-playbook/
- Code Reviews: required before merge
- Testing: unit, integration, e2e as appropriate
- CI/CD: automated pipelines
- Security: OWASP Top 10 compliance
- Observability: logging, metrics, tracing
- Agile: iterative delivery with feedback loops
```

## Claude Roles Structure

```markdown
## 🎭 CLAUDE ROLES

| Claude       | Role           | Assigned Tasks                                      | Files (NO OVERLAP!) |
| ------------ | -------------- | --------------------------------------------------- | ------------------- |
| **CLAUDE 1** | 🎯 COORDINATOR | Monitor plan, verify consistency, aggregate results | -                   |
| **CLAUDE 2** | 👨‍💻 IMPLEMENTER | [Task IDs]                                          | [file patterns]     |
| **CLAUDE 3** | 👨‍💻 IMPLEMENTER | [Task IDs]                                          | [file patterns]     |
| **CLAUDE 4** | 👨‍💻 IMPLEMENTER | [Task IDs]                                          | [file patterns]     |

> **MAX 4 CLAUDE** - Beyond becomes unmanageable and increases git conflict risk
```

### Role Descriptions

**CLAUDE 1 (COORDINATOR)**:

1. Monitor plan file every 10 minutes
2. Verify lint/typecheck/build pass at all times
3. Unlock gates when blocking phases complete
4. Help if another Claude gets stuck
5. Prepare final merge when all tasks are ✅

**CLAUDE 2, 3, 4 (IMPLEMENTERS)**:

1. Read ENTIRE plan before starting
2. Find tasks assigned to you (search "CLAUDE X")
3. For EACH task: read files → implement → verify → update plan
4. NEVER say "done" without running verification commands
5. If blocked: ASK instead of inventing solutions

## Execution Tracker Structure

```markdown
### Phase X: [Name] — 0/N [BLOCKS/Parallel with...]

| Status | ID   | Task          | Assignee     | Issue | Est | Started          | Ended            | Actual |
| :----: | ---- | ------------- | ------------ | :---: | :-: | ---------------- | ---------------- | :----: |
|   ⬜   | T-01 | [Description] | **CLAUDE 2** |  #XX  | 2h  |                  |                  |        |
|   🔄   | T-02 | [Description] | **CLAUDE 3** |  #XX  | 1h  | 2025-01-01 10:00 |                  |        |
|   ✅   | T-03 | [Description] | **CLAUDE 2** |  #XX  | 1h  | 2025-01-01 09:00 | 2025-01-01 09:45 |  45m   |

> ⚠️ **NOTES**: Any special instructions or dependencies
```

## Kitty Parallel Orchestration

### Inter-Claude Communication Protocol

All Claude instances can communicate using Kitty remote control.

#### Communication Command Pattern

```bash
# Universal pattern for ALL inter-Claude communication:
kitty @ send-text --match title:Claude-X "messaggio" && kitty @ send-key --match title:Claude-X Return
```

#### Communication Scenarios

**1. Coordinator → Worker (Task Assignment)**

```bash
kitty @ send-text --match title:Claude-3 "Leggi il piano, sei CLAUDE 3, inizia T-05" && kitty @ send-key --match title:Claude-3 Return
```

**2. Worker → Coordinator (Status Report)**

```bash
kitty @ send-text --match title:Claude-1 "CLAUDE 3: ✅ T-05 completato, piano aggiornato" && kitty @ send-key --match title:Claude-1 Return
```

**3. Worker → Worker (Direct Sync)**

```bash
kitty @ send-text --match title:Claude-4 "CLAUDE 2: Ho finito types.ts, puoi procedere con api.ts" && kitty @ send-key --match title:Claude-4 Return
```

**4. Broadcast (One → All)**

```bash
for i in 2 3 4; do
  kitty @ send-text --match title:Claude-$i "🚨 STOP! Conflitto git rilevato. Attendere." && kitty @ send-key --match title:Claude-$i Return
done
```

**5. Gate Unlock Notification**

```bash
kitty @ send-text --match title:Claude-3 "🟢 GATE-1 UNLOCKED! Procedi con Phase 1B" && kitty @ send-key --match title:Claude-3 Return
```

**6. Help Request**

```bash
kitty @ send-text --match title:Claude-1 "CLAUDE 4: ❓ Bloccato su T-08, errore typecheck. Puoi aiutare?" && kitty @ send-key --match title:Claude-1 Return
```

#### Message Format Convention

```
[SENDER]: [EMOJI] [CONTENT]

Examples:
- "CLAUDE 3: ✅ T-05 completato"
- "CLAUDE 1: 🚨 STOP! Git conflict"
- "CLAUDE 2: 🟢 GATE-1 UNLOCKED"
- "CLAUDE 4: ❓ Need help with T-08"
- "CLAUDE 1: 📊 Progress check: 45% complete"
```

#### Emojis for Quick Parsing

| Emoji | Meaning                  |
| :---: | ------------------------ |
|  ✅   | Task completed           |
|  🟢   | Gate unlocked / Go ahead |
|  🔴   | Stop / Blocked           |
|  🚨   | Alert / Urgent           |
|  ❓   | Question / Help needed   |
|  📊   | Status update            |
|  ⏳   | Waiting / In progress    |

## Thor Validation Gate

**Thor is Roberto's digital enforcer. NO Claude may claim "done" without Thor's approval.**

### Setup: Launch Thor as Dedicated Tab

```bash
~/.claude/scripts/thor-queue-setup.sh

kitty @ new-window --title "Thor-QA" --cwd [project_root]
kitty @ send-text --match title:Thor-QA "wildClaude" && kitty @ send-key --match title:Thor-QA Return
kitty @ send-text --match title:Thor-QA "You are Thor. Monitor /tmp/thor-queue/requests/ for validation requests." && kitty @ send-key --match title:Thor-QA Return
```

### Worker Validation Flow

```bash
# 1. Worker prepares validation request
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# 2. Create request file with evidence
cat > /tmp/thor-queue/requests/${REQUEST_ID}.json << EOF
{
  "request_id": "${REQUEST_ID}",
  "worker_id": "Claude-2",
  "task_reference": "W1-T03",
  "claim": "JWT authentication implemented",
  "evidence": {
    "test_output": "[paste actual test output]",
    "lint_output": "[paste actual lint output]",
    "git_branch": "$(git branch --show-current)",
    "git_status": "[paste actual git status]"
  }
}
EOF

# 3. Notify Thor
kitty @ send-text --match title:Thor-QA "[VALIDATION REQUEST] ${REQUEST_ID} from Claude-2" && kitty @ send-key --match title:Thor-QA Return

# 4. Wait for response
while [ ! -f /tmp/thor-queue/responses/${REQUEST_ID}.json ]; do sleep 5; done

# 5. Read response
cat /tmp/thor-queue/responses/${REQUEST_ID}.json
```

### Thor's Validation Process

1. **Read the original task** from the plan
2. **Verify EVERY requirement** was completed
3. **Run the tests himself** - not trust claims
4. **Challenge the worker**: "Are you BRUTALLY sure?"
5. **Invoke specialists** if needed
6. **APPROVE or REJECT** - no middle ground

### Response Handling

- **APPROVED**: Worker may mark task ✅ and proceed
- **REJECTED**: Worker MUST fix ALL issues and resubmit
- **CHALLENGED**: Worker MUST provide requested evidence
- **ESCALATED**: Worker STOPS and waits for Roberto

### Plan Template Addition

```markdown
## 🔱 THOR VALIDATION STATUS

| Worker   | Task   | Request ID | Status      | Retry |
| -------- | ------ | ---------- | ----------- | :---: |
| Claude-2 | W1-T03 | abc123     | ✅ APPROVED |   1   |
| Claude-3 | W1-T05 | def456     | ❌ REJECTED |   2   |

### Validation Queue

- Thor Tab: Thor-QA
- Queue Dir: /tmp/thor-queue/
- Protocol: .claude/protocols/thor-protocol.md

### Worker Reminder

⚠️ **YOU ARE NOT DONE UNTIL THOR SAYS YOU ARE DONE**
```

## Git Workflow with Worktrees

### STEP 0: Setup Worktrees (CLAUDE 1)

```bash
cd [project_root]

# Create branch for each phase
git checkout [main_branch]
git branch feature/[plan]-phase1
git branch feature/[plan]-phase2
git branch feature/[plan]-phase3

# Create worktree for each Claude
git worktree add ../[project]-C2 feature/[plan]-phase1
git worktree add ../[project]-C3 feature/[plan]-phase2
git worktree add ../[project]-C4 feature/[plan]-phase3

# Verify
git worktree list
```

### Mapping Claude → Worktree → Branch

| Claude   | Worktree          | Branch                | PR            |
| -------- | ----------------- | --------------------- | ------------- |
| CLAUDE 1 | `[project_root]`  | [main_branch]         | Coordina solo |
| CLAUDE 2 | `../[project]-C2` | feature/[plan]-phase1 | PR #1         |
| CLAUDE 3 | `../[project]-C3` | feature/[plan]-phase2 | PR #2         |
| CLAUDE 4 | `../[project]-C4` | feature/[plan]-phase3 | PR #3         |

### Send Claude to Worktrees

```bash
kitty @ send-text --match title:Claude-2 "cd ../[project]-C2" && kitty @ send-key --match title:Claude-2 Return
kitty @ send-text --match title:Claude-3 "cd ../[project]-C3" && kitty @ send-key --match title:Claude-3 Return
kitty @ send-text --match title:Claude-4 "cd ../[project]-C4" && kitty @ send-key --match title:Claude-4 Return
```

### PR Workflow

```bash
# 1. Commit
git add .
git commit -m "feat([scope]): Phase X - [description]

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

# 2. Push
git push -u origin feature/[plan]-phaseX

# 3. Create PR
gh pr create --title "feat([scope]): Phase X - [description]" --body "## Summary
- [bullet points]

## Issues Closed
- Closes #XX

## Verification
- [x] npm run lint ✅
- [x] npm run typecheck ✅
- [x] npm run build ✅

🤖 Generated with Claude Code" --base [main_branch]
```

### Merge & Cleanup (CLAUDE 1)

```bash
cd [project_root]

# 1. Merge all PRs (in order!)
gh pr merge [PR-1] --merge
gh pr merge [PR-2] --merge
gh pr merge [PR-3] --merge

# 2. Pull changes
git pull origin [main_branch]

# 3. Cleanup worktrees
git worktree remove ../[project]-C2
git worktree remove ../[project]-C3
git worktree remove ../[project]-C4

# 4. Cleanup branches
git branch -d feature/[plan]-phase1
git branch -d feature/[plan]-phase2
git branch -d feature/[plan]-phase3

# 5. Final verification
npm run lint && npm run typecheck && npm run build
```

## Phase Gates for Synchronization

### Add Phase Gates Section to Plan

```markdown
## 🚦 PHASE GATES

| Gate   | Blocking Phase   | Waiting Phases   | Status    | Unlocked By |
| ------ | ---------------- | ---------------- | --------- | ----------- |
| GATE-1 | Phase 0 (Safety) | Phase 1A, 1B, 1C | 🔴 LOCKED | CLAUDE 2    |
| GATE-2 | Phase 1 (All)    | Phase 2          | 🔴 LOCKED | CLAUDE 1    |
```

### Gate Status Values

- 🔴 LOCKED - Waiting phases cannot start
- 🟢 UNLOCKED - Waiting phases can proceed

### Unlock Protocol

When ALL tasks in blocking phase are ✅:

1. Update plan file - change gate status to 🟢 UNLOCKED
2. Notify waiting Claude instances:

```bash
kitty @ send-text --match title:Claude-3 "🟢 GATE-1 UNLOCKED! Start your Phase 1 tasks now." && kitty @ send-key --match title:Claude-3 Return
```

### Polling Protocol (for waiting Claude instances)

```bash
# Check gate status every 5 minutes:
grep "GATE-1" [plan_path] | grep -q "🟢 UNLOCKED" && echo "GO!" || echo "Still waiting..."

# Full polling loop:
while ! grep "GATE-1" [plan_path] | grep -q "🟢 UNLOCKED"; do
  echo "$(date): Waiting for GATE-1..."
  sleep 300  # 5 minutes
done
echo "🟢 GATE-1 UNLOCKED! Starting work..."
```

### Coordinator Responsibilities (CLAUDE 1)

```
CLAUDE 1 MUST:
1. Monitor all gates every 10 minutes
2. Verify gate unlocks are legitimate (all tasks ✅)
3. If a Claude forgets to unlock, do it for them
4. Track elapsed time per phase
5. Alert if a phase takes >2x estimated time
```

## ADR Template

```markdown
## ADR-XXX: [Decision Title]

| Field        | Value                                  |
| ------------ | -------------------------------------- |
| **Status**   | ✅ Accepted / ⏸️ Pending / ❌ Rejected |
| **Date**     | YYYY-MM-DD                             |
| **Deciders** | [Names]                                |

**Context**: [Why is this decision needed?]

**Decision**: [What was decided]

**Rationale**: [Why this option was chosen]

**Consequences**:

- (+) [Positive outcomes]
- (-) [Trade-offs or drawbacks]
```
