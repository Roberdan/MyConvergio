---
name: planner
version: "2.0.0"
---

<!-- v2.0.0 (2026-02-15): Compact format per ADR 0009 -->

# Planner + Orchestrator

Plan and execute with parallel Claude instances.

## CRITICAL RULES (NON-NEGOTIABLE)

| #   | Rule                                                                                                                                                              |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Task Executor MANDATORY**: Use `Task(subagent_type='task-executor')` for EVERY task                                                                             |
| 2   | **F-xx Requirements**: Extract ALL. Nothing done until ALL verified [x]                                                                                           |
| 3   | **User Approval Gate**: BLOCK until explicit "si"/"yes"/"procedi"                                                                                                 |
| 4   | **Thor Enforcement**: Task done = per-task Thor passed. Wave done = per-wave Thor + build passed. Gate 9 MANDATORY.                                               |
| 5   | **Worktree Isolation**: EVERY task prompt MUST include worktree path                                                                                              |
| 6   | **Knowledge Codification**: Errors -> ADR + ESLint. Thor validates. See @planner-modules/knowledge-codification.md                                                |
| 7   | **NO SILENT EXCLUSIONS**: NEVER exclude/defer ANY F-xx without EXPLICIT user approval via AskUserQuestion. Silently dropping = VIOLATION.                         |
| 8   | **MINIMIZE HUMAN INTERVENTION**: Explore automated alternatives first. Only mark `manual` if no alternative. Consolidate+front-load to W0. See [Rule 8](#rule-8). |
| 9   | **EFFORT LEVEL MANDATORY**: Every task MUST have `"effort": 1\|2\|3`. 1=trivial, 2=standard, 3=complex.                                                           |
| 10  | **PR + CI CLOSURE TASK**: Final wave MUST include `TF-pr` task. Plan NOT done until TF-pr done+Thor-validated. See [Closure](#final-closure).                     |
| 11  | **TEST CONSOLIDATION**: Final wave MUST include `TF-tests` task BEFORE `TF-pr`. See [Test Consolidation](#test-consolidation).                                    |

## Module References

| Topic                  | Module                                     |
| ---------------------- | ------------------------------------------ |
| Parallelization modes  | @planner-modules/parallelization-modes.md  |
| Model strategy         | @planner-modules/model-strategy.md         |
| Knowledge codification | @planner-modules/knowledge-codification.md |

## Workflow

### 1. Init

```bash
export PATH="$HOME/.claude/scripts:$PATH"
CONTEXT=$(planner-init.sh)
PROJECT_ID=$(echo "$CONTEXT" | jq -r '.project_id')
```

Returns: project_id, project_name, path, branch, active_plans, worktrees, has_adr, has_changelog, prompt_files. Auto-registers. All ops INSIDE worktree.

### 1.5 Read Existing Docs (MANDATORY)

NO Explore. Direct Glob/Grep (2 calls): `Glob("docs/adr/*.md")`, `Grep(pattern="kw1|kw2", path="docs/adr/", output_mode="files_with_matches")`. Read matched ADRs. Check CHANGELOG.md last 20 lines. Cite ADRs in `ref`. Conflict = ASK.

### 1.6 Technical Clarification (MANDATORY)

After reading, STOP. AskUserQuestion: 1. **Approach**: "Per F-xx propongo [A]. Alternative: [B, C]. Preferenze?" 2. **Files**: "File coinvolti: [list]. Altri?" 3. **Constraints**: "Breaking changes ok? Nuove dipendenze? Vincoli?" If GUESSING -> ASK.

### 1.7 Repo Hardening Gate (FIRST PLAN ONLY)

On first plan for a project (no prior plans in DB), run:

```bash
HARDENING=$(~/.claude/scripts/hardening-check.sh "$WORKTREE_PATH")
HARDENING_STATUS=$(echo "$HARDENING" | jq -r '.status')
```

- If `pass`: proceed silently.
- If `gaps_found`: check severity. If ANY `critical` gap: add W0-01 task `"Run /harden skill to fix critical quality gaps"`. If only `warning`/`info`: present gaps to user via AskUserQuestion, let them decide.
- W0 task uses `/harden` skill for full remediation (hooks, lint, scripts, PR template, ADR structure).

### 2. Generate Plan Spec (JSON)

**EXCLUSION GATE**: Compare ALL F-xx vs tasks. If ANY NOT covered: 1. List uncovered. 2. AskUserQuestion: "Requisiti non coperti: [list]. Per ciascuno: includerli, deferirli, o escluderli?" 3. BLOCK. NEVER silently skip with "scope.out", "backlog", "needs external resource".

spec.json: `{user_request, requirements:[{id,text,wave}], waves:[{id,name,estimated_hours,tasks:[{id,do,files,verify,ref,priority,type,model,effort}]}]}`

**Rules**: `do`=ONE action. `files`=explicit paths. `verify`=machine-checkable. `ref`=F-xx ID. Missing `verify`=broken. **Per-wave docs**: TX-doc (CHANGELOG + plan-{id}-notes.md). **Final wave** "WF-Closure": TF-01 (notes->ADRs), TF-02 (CHANGELOG), TF-03 (ESLint), TF-tests (test consolidation), TF-pr (PR+CI). Cite ADRs in `do`.

### 2.5 Copilot-First Delegation (DEFAULT)

**ALL tasks default to `executor_agent: "copilot"`.** Only escalate to `claude` per decision tree in @planner-modules/model-strategy.md. Present summary: "Task su Claude (pagati): [list + perche']. Tutto il resto su Copilot (gratis). Ok?"

**Copilot model assignment**: trivial -> `gpt-5.1-codex-mini` | standard -> `gpt-5.3-codex` | complex -> `claude-opus-4.6-fast`. See model-strategy for full tree.

**Never delegate to Copilot**: architecture decisions, security-sensitive, investigative debugging, cross-system integration where failure cascades.

**Exec**: `copilot-worker.sh <id> --model <model> --timeout 600`. Requires: `copilot --allow-all`, `GH_TOKEN`.

### 2.7 Cross-Plan Conflict Check (MANDATORY)

```bash
CONFLICT_REPORT=$(plan-db.sh conflict-check-spec $PROJECT_ID /path/to/spec.json)
RISK=$(echo "$CONFLICT_REPORT" | jq -r '.overall_risk')
```

If risk != "none", AskUserQuestion: Merge | Sequence | Parallel | Abort. If risk == "none", proceed silently.

### 3. Create Plan + Import

```bash
PROMPT_FILE=".copilot-tracking/prompt-{NNN}.json"
PLAN_ID=$(plan-db.sh create $PROJECT_ID "{PlanName}" --source-file "$PROMPT_FILE" --auto-worktree \
  --human-summary "2-3 righe in italiano che spiegano COSA fa il piano per un umano. Mostrato in dashboard.")
plan-db.sh import $PLAN_ID /path/to/spec.json
WORKTREE_PATH=$(plan-db.sh get-worktree $PLAN_ID)
cd "$WORKTREE_PATH"
```

**`--human-summary` MANDATORY**: Riassunto leggibile del piano (NO path, NO istruzioni agente, NO workflow). Max 200 chars. Esempio: "Rinomina deployment Azure OpenAI da gpt-4o-realtime a gpt-realtime in tutti i file di configurazione e secrets"

### 4. User Approval (MANDATORY STOP)

Present F-xx + Codex proposals. "si"/"yes" -> Proceed.

### 5. Parallelization Mode

See @planner-modules/parallelization-modes.md. AskUserQuestion: Standard (3) vs Max (unlimited, Opus).

### 6. Start

```bash
plan-db.sh start $PLAN_ID
```

### 6.5 Preconditions (F-08)

Tasks support preconditions to control execution flow:

| Field             | Purpose                       | Example                                                |
| ----------------- | ----------------------------- | ------------------------------------------------------ |
| `skip_if`         | Skip task when condition met  | `"skip_if": "test -f .env"`                            |
| `output_match`    | Validate prior task output    | `"output_match": {"task": "T1-01", "pattern": "PASS"}` |
| `wave_status`     | Require wave state before run | `"wave_status": {"W1": "done"}`                        |
| `check-readiness` | Pre-flight check before wave  | `plan-db.sh check-readiness $PLAN_ID $WAVE_ID`         |

Executor MUST evaluate preconditions before starting. Skip=logged, fail=blocked.

### 7. Execute Tasks

Use `/execute {plan_id}`. Manual: `await Task({subagent_type: "task-executor", model: task.model, max_turns: 30, prompt: "Project: {id} | Plan: {plan_id} | Task: T1-01\n**WORKTREE**: {path}\nF-xx: [criteria]"})`

### 8. Thor Validation (MANDATORY)

**8a. Per-Task**: `Task(subagent_type="thor", model="sonnet", prompt="THOR PER-TASK\nPlan:{plan_id}|Task:{task_id}|Wave:{wave_id}\nWORKTREE:{path}\ndo:{desc}|type:{type}|verify:{criteria}|ref:{F-xx}|files:{files}\nRun verify. Gate 1-4,8,9. Read files.")` -> `plan-db.sh validate-task {task_id} {plan_id}`

**8b. Per-Wave**: `Task(subagent_type="thor", model="sonnet", prompt="THOR PER-WAVE\nPlan:{plan_id}|Wave:{wave_id}(db:{db_id})\nWORKTREE:{path}|FRAMEWORK:{framework}\nTasks:[list]|Verify:[all]\nALL 9 gates. lint,typecheck,build,tests. F-xx cross-task. Read files.")` -> `plan-db.sh validate-wave {wave_db_id}`

NEVER skip. NEVER trust executor. Thor reads files. Per-task MANDATORY. Per-wave AFTER all per-task. Progress=Thor-validated only. Gate 9=ADR-Smart for docs.

### 9. Knowledge Codification

See @planner-modules/knowledge-codification.md. LEARNINGS LOG -> ADRs -> ESLint -> Thor validates.

## Rule 8: Minimize Human Intervention {#rule-8}

Before marking `manual`, explore alternatives:

| Human task type        | Automated alternative                         |
| ---------------------- | --------------------------------------------- |
| "Test on mobile"       | Playwright mobile viewport + BrowserStack API |
| "Visual QA"            | Percy/Chromatic screenshot diffing            |
| "Bug bash"             | Smoke test suite                              |
| "Verify in production" | Synthetic monitoring + health checks          |
| "User acceptance"      | E2E test matching acceptance criteria         |
| "Manual API test"      | Integration tests with real endpoints         |

When unavoidable: 1. Consolidate. 2. Front-load to W0. 3. Provide checklist. 4. Never "blocked" without instructions.

## Test Consolidation {#test-consolidation}

EVERY plan MUST include `TF-tests` in the final wave, BEFORE `TF-pr`:

`{"id": "TF-tests", "do": "Consolidate, deduplicate, and optimize all test files touched or created in this plan", "files": ["tests/"], "verify": ["bash -c 'for t in tests/test-*.sh; do bash \"$t\" || exit 1; done'", "No duplicate setup/teardown across test files", "All tests use SCRIPT_DIR pattern for portable paths"], "ref": "F-closure", "priority": "P0", "type": "test", "model": "sonnet", "effort": 2}`

**What TF-tests MUST do:**

| Check              | Action                                                                                                      |
| ------------------ | ----------------------------------------------------------------------------------------------------------- |
| **Duplicates**     | Find tests checking the same behavior across files. Merge into one authoritative test                       |
| **Shared setup**   | Extract repeated setup/teardown into `tests/lib/test-helpers.sh` (create if missing)                        |
| **Portable paths** | All tests use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` — no hardcoded absolute paths |
| **Categorize**     | Prefix: `test-unit-*` (fast, no I/O), `test-integration-*` (DB/network), `test-e2e-*` (full flow)           |
| **Cleanup**        | Remove empty/broken test files, RED-phase leftovers (`exit 1`), bats syntax in bash files                   |
| **Run all**        | Execute every test, 0 failures required before TF-pr                                                        |

**Why**: Without this gate, tests accumulate without consolidation. Each task adds its own tests independently, leading to duplicated setup, fragile paths, conflicting patterns, and hour-long CI runs that fail for unrelated reasons.

## Final Closure {#final-closure}

EVERY plan MUST end with `TF-pr` task: `{"id": "TF-pr", "do": "Create PR, ensure CI passes, resolve comments, confirm merge-ready", "files": [], "verify": ["gh pr view --json state,statusCheckRollup | jq '.statusCheckRollup[] | select(.conclusion != \"SUCCESS\")'"], "ref": "F-closure", "priority": "P0", "type": "chore", "model": "sonnet", "effort": 2}`

**Workflow**: 1. `gh pr create`. 2. Wait CI. 3. If fail: fix, push, wait (max 3). 4. If review: address, push, resolve. 5. Confirm: `gh pr view --json mergeable` = `MERGEABLE`. 6. Report: URL + CI + merge readiness.

Plan NOT done until TF-pr done+Thor-validated.

## Cross-Tool Execution

Plan created by one tool but executed by another: Executing tool gets `T0-00 Review Plan` first (see @planner-modules/model-strategy.md). Allows model/effort reassignment. spec.json = handoff contract.

## State Transitions

`pending -> in_progress -> done|blocked|skipped`

Forbidden: `done -> pending`, `skipped -> done`
