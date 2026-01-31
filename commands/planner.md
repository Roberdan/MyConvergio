# Planner + Orchestrator

Plan and execute with parallel Claude instances.

## Context (pre-computed)
```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Worktree: `git rev-parse --show-toplevel 2>/dev/null || pwd`
Active plans: `sqlite3 ~/.claude/data/dashboard.db "SELECT id, name, status FROM plans WHERE status IN ('todo','doing') LIMIT 3;" 2>/dev/null || echo "none"`
```

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL requirements. Nothing done until ALL verified [x]
3. **User Approval Gate**: BLOCK until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed
5. **Worktree Isolation**: EVERY task prompt MUST include worktree path
6. **Knowledge Codification**: Errors → ADR + ESLint. Thor validates. See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

## Module References

| Topic | Module |
|-------|--------|
| Parallelization modes | [parallelization-modes.md](./planner-modules/parallelization-modes.md) |
| Model strategy | [model-strategy.md](./planner-modules/model-strategy.md) |
| Knowledge codification | [knowledge-codification.md](./planner-modules/knowledge-codification.md) |

## Workflow

### 1. Setup
```bash
export PATH="$HOME/.claude/scripts:$PATH"
MAIN_REPO=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_NAME=$(basename "$MAIN_REPO")
PROMPT_FILE=".copilot-tracking/prompt-{NNN}.md"
PLAN_MD="~/.claude/plans/{project}/{PlanName}-Main.md"

# 1a. Create plan in DB (without worktree yet)
PLAN_ID=$(plan-db.sh create {project_id} "{PlanName}" \
  --source-file "$PROMPT_FILE" \
  --markdown-path "$PLAN_MD")

# 1b. MANDATORY: Create dedicated worktree for this plan
PLAN_SLUG=$(echo "{PlanName}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')
WORKTREE_BRANCH="plan/${PLAN_ID}-${PLAN_SLUG}"
WORKTREE_PATH="${MAIN_REPO}/../${REPO_NAME}-plan-${PLAN_ID}"
~/.claude/scripts/worktree-create.sh "$WORKTREE_BRANCH" "$WORKTREE_PATH"

# 1c. Store worktree path in DB
plan-db.sh set-worktree $PLAN_ID "$WORKTREE_PATH"

# 1d. Switch to worktree for all subsequent operations
cd "$WORKTREE_PATH"
~/.claude/scripts/worktree-check.sh "$WORKTREE_PATH"
```

**RULE**: All subsequent operations (ADR reads, file analysis, task creation) happen INSIDE the worktree.
The main repo is NEVER modified directly - only via worktree branches.

### 1.5 Read Existing Documentation (MANDATORY before plan)

Before planning, READ existing docs to avoid repeating solved problems:

```bash
# Scan relevant ADRs
ls docs/adr/*.md | head -20   # List existing ADRs
# Read ADRs related to the feature area (grep for keywords from prompt)
grep -rl "keyword" docs/adr/ | head -5
# Check CHANGELOG for recent decisions
head -50 CHANGELOG.md
```

**Use ADRs to inform the plan**: If an ADR says "use X pattern" or "avoid Y approach", the plan MUST follow it.
**Cite ADRs in task descriptions**: e.g., "Per ADR 0082, use namespace-scoped i18n files."
**Conflict = ASK user**: If prompt conflicts with existing ADR, ask before proceeding.

### 1.6 Technical Clarification (MANDATORY before plan)

After reading prompt + docs, STOP. Identify ambiguities. Use AskUserQuestion.

**Always ask:**
1. **Approach**: "Per F-xx propongo [approccio]. Alternative: [B, C]. Preferenze?"
2. **File scope**: "I file coinvolti: [list]. Altri da toccare? Qualcuno da NON toccare?"
3. **Constraints**: "Breaking changes ok? Nuove dipendenze? Vincoli tecnici?"

**Ask if complex:** Test strategy, migration needs, performance requirements.

**Rule**: If GUESSING about implementation → STOP and ASK.

### 2. Plan File (`~/.claude/plans/{project}/{PlanName}-Main.md`)
```markdown
# Piano: {Name}
**Project**: {id} | **Status**: draft | **Worktree**: {path}

## USER REQUEST
> [exact words]

## FUNCTIONAL REQUIREMENTS
| ID | Requirement | Wave | Verified |
|----|-------------|------|----------|
| F-01 | [from user] | W1 | [ ] |

## WAVES
| Task | Description | F-xx | Model | Status |
|------|-------------|------|-------|--------|
| T1-01 | [task] | F-01 | sonnet | pending |

## LEARNINGS LOG
| Wave | Issue | Root Cause | Resolution | Preventive Rule |
|------|-------|------------|------------|-----------------|

## MANDATORY FINAL TASK (always last wave)
| Task | Description | F-xx | Model | Status |
|------|-------------|------|-------|--------|
| TF-01 | Update/create ADRs for learnings from this plan | - | sonnet | pending |
| TF-02 | Update CHANGELOG.md with plan changes | - | haiku | pending |
| TF-03 | Create ESLint rules for automatable learnings | - | sonnet | pending |
```

### 3. Register in DB

**MANDATORY**: For EVERY task, extract acceptance criteria from the prompt file and set `--test-criteria`. The `--description` MUST contain what to do, which files to touch, and the F-xx reference.

```bash
plan-db.sh add-wave {plan_id} "W1" "Phase"
plan-db.sh add-task {db_wave_id} T1-01 "Fix i18n loading" P1 feature \
  --model sonnet \
  --description "Change Object.assign to namespace-scoped in src/i18n/request.ts. See F-03." \
  --test-criteria '{"verify":["npm run i18n:check passes","0 ESLint i18n warnings","build succeeds"]}'
```

Rules:
- `--description`: what + which files + F-xx ref + relevant ADR (one sentence)
- `--test-criteria`: JSON array of verifiable checks from prompt acceptance criteria
- Missing test_criteria = Thor cannot validate = pipeline broken
- **MANDATORY**: Always create a final wave "WF-Documentation" with tasks TF-01/02/03 (ADR, CHANGELOG, ESLint)
- Task descriptions MUST cite relevant existing ADRs (e.g., "Per ADR 0082...")

### 3.5 Codex Delegation Tagging (MANDATORY)

Review each task against Codex delegation criteria (see `~/.claude/rules/codex-delegation.md`).

**Tag as `codex: true`** if task is: translations, bulk renames, boilerplate, JSON/config updates, repetitive test generation, >500 lines of simple edits.

```bash
# For codex-eligible tasks, add metadata
plan-db.sh update-task {db_task_id} pending "Codex-eligible" \
  --notes "codex: true | prompt: Translate all Italian strings in messages/de/*.json to German"
```

**Present to user**: "Questi task sono delegabili a Codex: [list]. Vuoi delegarli? (aspetto 1 min, poi procedo io)"

**Never delegate**: architectural decisions, security code, debugging, cross-cutting logic, CI/build, DB schema, API design.

### 4. User Approval (MANDATORY STOP)
Present F-xx list + Codex delegation proposals → User says "si"/"yes" → Proceed

### 5. Parallelization Mode Selection
> See [parallelization-modes.md](./planner-modules/parallelization-modes.md)

Ask via AskUserQuestion: Standard (3 parallel) vs Max (unlimited, Opus).

### 6. Start Execution
```bash
plan-db.sh start {plan_id}  # MANDATORY: moves to IN FLIGHT
```

### 7. Execute Tasks
Use `/execute {plan_id}` for automated execution.

Manual fallback:
```typescript
await Task({
  subagent_type: "task-executor",
  model: task.model,  // From DB
  prompt: `Project: {id} | Plan: {plan_id} | Task: T1-01
  **WORKTREE**: {absolute_worktree_path}
  F-xx: [acceptance criteria]`
});
```

### 8. Thor Validation (per wave) - MANDATORY

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates Wave WX",
  prompt="THOR VALIDATION SESSION
  Plan ID: {plan_id}
  Wave: {wave_id}
  Plan Markdown: {PLAN_MD}
  Source Prompt: {PROMPT_FILE}
  WORKTREE: {WORKTREE_PATH}
  F-xx Requirements: [list from plan markdown]

  Validate this wave. Read plan markdown for F-xx and task specs."
)
```

After Thor PASS:
```bash
plan-db.sh validate {plan_id}
npm run ci:summary
```

**Rules**: NEVER skip Thor. NEVER trust executor reports. Thor reads files directly.

### 9. Knowledge Codification (pre-closure)
> See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

Update LEARNINGS LOG → Create ADRs → Create ESLint rules → Thor validates.

## State Transitions
`pending → in_progress → done|blocked|skipped`
Forbidden: `done → pending`, `skipped → done`
