# Planner + Orchestrator

Plan and execute with parallel Claude instances.

## CRITICAL RULES (NON-NEGOTIABLE)

1. **Task Executor MANDATORY**: Use `Task(subagent_type='task-executor')` for EVERY task
2. **F-xx Requirements**: Extract ALL requirements. Nothing done until ALL verified [x]
3. **User Approval Gate**: BLOCK until explicit "si"/"yes"/"procedi"
4. **Thor Enforcement**: Wave done = Thor passed + build passed
5. **Worktree Isolation**: EVERY task prompt MUST include worktree path
6. **Knowledge Codification**: Errors -> ADR + ESLint. Thor validates. See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

## Module References

| Topic                  | Module                                                                   |
| ---------------------- | ------------------------------------------------------------------------ |
| Parallelization modes  | [parallelization-modes.md](./planner-modules/parallelization-modes.md)   |
| Model strategy         | [model-strategy.md](./planner-modules/model-strategy.md)                 |
| Knowledge codification | [knowledge-codification.md](./planner-modules/knowledge-codification.md) |

## Workflow

### 1. Init (single call)

```bash
export PATH="$HOME/.claude/scripts:$PATH"
CONTEXT=$(planner-init.sh)
PROJECT_ID=$(echo "$CONTEXT" | jq -r '.project_id')
echo "$CONTEXT" | jq .
```

This returns: project_id, project_name, path, branch, active_plans, worktrees, has_adr, has_changelog, prompt_files. Auto-registers project if missing.

**RULE**: All subsequent operations happen INSIDE the worktree (created in step 3).

### 1.5 Read Existing Documentation (MANDATORY before plan)

**DO NOT use Explore agent for ADRs. Use direct Glob/Grep (2 calls max):**

```bash
# 1. List ADR titles (one Glob call)
Glob("docs/adr/*.md")

# 2. Grep for keywords related to the feature (one Grep call)
Grep(pattern="keyword1|keyword2", path="docs/adr/", output_mode="files_with_matches")
```

Then Read ONLY the matched ADR files (not all of them).
Also check CHANGELOG.md last 20 lines for recent decisions.

**Cite relevant ADRs in task `ref` fields. Conflict = ASK user.**

### 1.6 Technical Clarification (MANDATORY before plan)

After reading prompt + docs, STOP. Identify ambiguities. Use AskUserQuestion.

**Always ask:**

1. **Approach**: "Per F-xx propongo [approccio]. Alternative: [B, C]. Preferenze?"
2. **File scope**: "I file coinvolti: [list]. Altri da toccare? Qualcuno da NON toccare?"
3. **Constraints**: "Breaking changes ok? Nuove dipendenze? Vincoli tecnici?"

**Rule**: If GUESSING about implementation -> STOP and ASK.

### 2. Generate Plan Spec (JSON)

Write a `spec.json` file with compact task format optimized for machine execution:

```json
{
  "user_request": "exact user words from prompt",
  "requirements": [
    { "id": "F-01", "text": "requirement description", "wave": "W1" }
  ],
  "waves": [
    {
      "id": "W1-Name",
      "name": "Wave description",
      "estimated_hours": 8,
      "tasks": [
        {
          "id": "T1-01",
          "do": "atomic action: what to implement",
          "files": ["src/path/file.ts", "src/path/other.ts"],
          "verify": ["grep -q 'pattern' file.ts", "npm test -- file.test.ts"],
          "ref": "F-01",
          "priority": "P1",
          "type": "feature",
          "model": "sonnet"
        }
      ]
    }
  ]
}
```

**Compact format rules:**

- `do`: ONE atomic action. If you need "and", split into 2 tasks.
- `files`: explicit file paths the task-executor must touch. No guessing.
- `verify`: machine-checkable commands. `grep`, `test`, `npm test -- file`. Not prose.
- `ref`: F-xx requirement ID this task satisfies
- Missing `verify` = Thor cannot validate = pipeline broken
- **MANDATORY per-wave docs**: EVERY wave MUST end with a documentation task:
  ```json
  {
    "id": "TX-doc",
    "do": "Update CHANGELOG.md with WX changes + append learnings to docs/adr/plan-{id}-notes.md",
    "description": "CHANGELOG: ## [Unreleased] / ### WX: {name} / - Added|Changed|Fixed: ... / Running notes: ## WX: {name} / - Decision: {1 line} / - Issue: ... → Fix: ... / - Pattern: {insight}",
    "files": ["CHANGELOG.md", "docs/adr/plan-{id}-notes.md"],
    "verify": ["grep -q 'WX' CHANGELOG.md"],
    "ref": "F-docs",
    "type": "documentation",
    "model": "sonnet"
  }
  ```
  The `description` field carries the format template so the executor doesn't need to look it up.
- **MANDATORY final wave** "WF-Documentation":
  - TF-01: Convert running notes → formal ADRs (compact format, see knowledge-codification.md)
  - TF-02: Finalize CHANGELOG.md (merge per-wave entries, add version header)
  - TF-03: Create ESLint rules for automatable learnings
- Task `do` fields MUST cite relevant existing ADRs when applicable

### 2.5 Copilot Delegation Tagging

Review each task against delegation criteria (see CLAUDE.md).
Mark eligible tasks in spec with `"codex": true`.
Present: "Questi task sono delegabili a Copilot: [list]. Vuoi delegarli?"
**Never delegate**: architecture, security, debugging, cross-cutting logic, CI/build, DB schema, API design.

**Prompt enrichment** (MANDATORY): Use `copilot-task-prompt.sh <db_task_id>` which auto-includes:

- Task `do` + `files` + `verify` from DB
- Worktree guard enforcement (NEVER on main)
- TDD workflow + plan-db.sh update commands
- Coding standards inline

**Execution modes for delegated tasks**:

- **Kitty orchestration**: `worker-launch.sh copilot "Copilot-N" <id> --cwd <worktree>`
- **Standalone**: `copilot-worker.sh <id> --model claude-sonnet-4-5 --timeout 600`
- **Mixed mode**: `orchestrate.sh <plan> 4 --engine mixed` (auto-routes by codex flag)

Copilot CLI requires: `copilot --allow-all` (no confirmations), `GH_TOKEN` set.

### 3. Create Plan + Import (2 calls total)

```bash
PROMPT_FILE=".copilot-tracking/prompt-{NNN}.json"

# Single command: creates plan + worktree
PLAN_ID=$(plan-db.sh create $PROJECT_ID "{PlanName}" \
  --source-file "$PROMPT_FILE" --auto-worktree)

# Single command: bulk imports waves+tasks from spec
plan-db.sh import $PLAN_ID /path/to/spec.json

# Switch to worktree
WORKTREE_PATH=$(plan-db.sh get-worktree $PLAN_ID)
cd "$WORKTREE_PATH"
```

### 4. User Approval (MANDATORY STOP)

Present F-xx list + Codex delegation proposals. User says "si"/"yes" -> Proceed.

### 5. Parallelization Mode Selection

> See [parallelization-modes.md](./planner-modules/parallelization-modes.md)

Ask via AskUserQuestion: Standard (3 parallel) vs Max (unlimited, Opus).

### 6. Start Execution

```bash
plan-db.sh start $PLAN_ID
```

### 7. Execute Tasks

Use `/execute {plan_id}` for automated execution.

Manual fallback:

```typescript
await Task({
  subagent_type: "task-executor",
  model: task.model,
  max_turns: 30,
  prompt: `Project: {id} | Plan: {plan_id} | Task: T1-01
  **WORKTREE**: {absolute_worktree_path}
  F-xx: [acceptance criteria]`,
});
```

### 8. Thor Validation (per wave) - MANDATORY

Thor gets task data from DB context, not from markdown files.

```
Task(
  subagent_type="thor-quality-assurance-guardian",
  model="sonnet",
  description="Thor validates Wave WX",
  prompt="THOR VALIDATION
  Plan: {plan_id} | Wave: {wave_id} (db_id: {wave_db_id})
  WORKTREE: {WORKTREE_PATH} | FRAMEWORK: {framework}
  Tasks in wave: [list task_ids + titles from CTX]
  Verify criteria: [list test_criteria for each task in wave]
  Run: lint, typecheck, build, tests. Check F-xx. Read files directly."
)
```

After Thor PASS:

```bash
plan-db.sh validate {plan_id}
```

**Rules**: NEVER skip Thor. NEVER trust executor reports. Thor reads files directly.

### 9. Knowledge Codification (pre-closure)

> See [knowledge-codification.md](./planner-modules/knowledge-codification.md)

Update LEARNINGS LOG -> Create ADRs -> Create ESLint rules -> Thor validates.

## State Transitions

`pending -> in_progress -> done|blocked|skipped`
Forbidden: `done -> pending`, `skipped -> done`
