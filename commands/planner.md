---
name: planner
version: "2.3.0"
---

<!-- v2.0.0 (2026-02-15): Compact format per ADR 0009 -->

# Planner + Orchestrator

Plan and execute with parallel Claude instances.

## CRITICAL RULES (NON-NEGOTIABLE)

| #   | Rule                                                                                                                                                                                                                                                                            |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Task Executor MANDATORY**: NEVER edit files directly while a plan is active. Direct edit = Thor bypass = VIOLATION. See CLAUDE.md Anti-Bypass.                                                                                                                                |
| 2   | **F-xx Requirements**: Extract ALL. Nothing done until ALL verified [x]                                                                                                                                                                                                         |
| 3   | **User Approval Gate**: BLOCK until explicit "si"/"yes"/"procedi"                                                                                                                                                                                                               |
| 4   | **Thor Enforcement**: Task done = per-task Thor passed. Wave done = per-wave Thor + build passed. Gate 9 MANDATORY.                                                                                                                                                             |
| 5   | **Worktree Isolation**: EVERY task prompt MUST include worktree path. Wave-level worktrees are the default; plan-level is deprecated.                                                                                                                                           |
| 6   | **Knowledge Codification**: Errors -> ADR + ESLint. Thor validates. See @planner-modules/knowledge-codification.md                                                                                                                                                              |
| 7   | **NO SILENT EXCLUSIONS**: NEVER exclude/defer ANY F-xx without EXPLICIT user approval via AskUserQuestion. Silently dropping = VIOLATION.                                                                                                                                       |
| 8   | **MINIMIZE HUMAN INTERVENTION**: Explore automated alternatives first. Only mark `manual` if no alternative. Consolidate+front-load to W0. See [Rule 8](#rule-8).                                                                                                               |
| 9   | **EFFORT LEVEL MANDATORY**: Every task MUST have `"effort": 1\|2\|3`. 1=trivial, 2=standard, 3=complex.                                                                                                                                                                         |
| 10  | **PR + CI CLOSURE TASK**: Final wave MUST include `TF-pr` task. Plan NOT done until TF-pr done+Thor-validated. See [Closure](#final-closure).                                                                                                                                   |
| 11  | **TEST CONSOLIDATION**: Final wave MUST include `TF-tests` task BEFORE `TF-pr`. See [Test Consolidation](#test-consolidation).                                                                                                                                                  |
| 12  | **INFRA TASK DISCIPLINE (ADR-054)**: Infrastructure tasks (Azure CLI, Bicep, cloud ops) follow SAME plan-db discipline as code. Interactive `az` commands MUST update plan-db before/after. Batch updates at session end = VIOLATION. Hook `warn-infra-plan-drift.sh` enforces. |
| 13  | **COPILOT-FIRST DELEGATION**: EVERY task MUST have explicit `executor_agent` assignment. Default=copilot. Skipping step 2.5 = VIOLATION. See [Step 2.5](#step-2-5).                                                                                                             |
| 14  | **PLAN INTELLIGENCE REVIEW**: Steps 3.1-3.2 MANDATORY for plans with 3+ tasks. Skipping = VIOLATION. See [Step 3.1](#step-3-1).                                                                                                                                                 |
| 15  | **TEST ADAPTS TO CODE**: When implementation changes break existing tests, update tests to match new behavior. NEVER revert implementation to make old tests pass. Tests follow code, not the opposite.                                                                         |

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

### 1.5 Read Existing Docs + Failed Approaches (MANDATORY)

NO Explore. Direct Glob/Grep (2 calls): `Glob("docs/adr/*.md")`, `Grep(pattern="kw1|kw2", path="docs/adr/", output_mode="files_with_matches")`. Read matched ADRs. Check CHANGELOG.md last 20 lines. Cite ADRs in `ref`. Conflict = ASK.

**Failed Approaches Check** (HVE Core pattern): `plan-db.sh get-failures $PROJECT_ID`. If prior failures exist for this project, list them and ensure the new plan DOES NOT repeat the same approach. Reference failures in task `do` field: "Previous attempt X failed because Y — use Z instead."

**Plan Intelligence Queries** (parallel, all optional — skip on DB error):

```bash
# Actionable learnings from past plans
LEARNINGS=$(plan-db.sh get-actionable-learnings $PROJECT_ID)
# Calibrated token estimates from historical actuals
CALIBRATED=$(plan-db.sh calibrate-estimates $PROJECT_ID)
# Recurring patterns: same category+title in 3+ plans = codify as reusable
PATTERNS=$(plan-db.sh get-actionable-learnings $PROJECT_ID | jq '[.[] | select(.occurrences >= 3)]')
```

Apply learnings: adjust effort estimates using `CALIBRATED` data, cite recurring patterns in task `do` fields ("Per learning L-xx: use approach Y"), flag anti-patterns from `LEARNINGS` with severity=high.

### 1.6 Constraint Extraction (MANDATORY — ADR-054)

Extract ALL constraints from user brief BEFORE generating tasks. Constraints are hard limits that NO task may violate.

**Common constraint categories**: `permission` (no admin needed), `security` (no secrets in code), `cost` (budget limits), `compliance` (GDPR, single-tenant), `technical` (Python version, no breaking changes), `process` (no downtime, rollback required).

**Extraction rules**:

1. Read user brief for words: "never", "must not", "no", "without requiring", "only", "always", "non-negotiable"
2. Each constraint gets `C-xx` ID, clear text, type, and machine-checkable `verify` where possible
3. AskUserQuestion: "Ho estratto questi vincoli: [list]. Ne mancano? Ce ne sono altri impliciti?"
4. BLOCK if constraints empty — every plan has at least one (e.g., "no breaking changes")

**Validation gate**: After spec generation, verify EVERY task against EVERY constraint. If task violates a constraint → remove task or redesign. Present conflict table to user.

### 1.7 Technical Clarification (MANDATORY)

After reading, STOP. AskUserQuestion: 1. **Approach**: "Per F-xx propongo [A]. Alternative: [B, C]. Preferenze?" 2. **Files**: "File coinvolti: [list]. Altri?" 3. **Constraints**: "Confermo vincoli C-xx. Breaking changes ok? Nuove dipendenze?" If GUESSING -> ASK.

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

spec.json: `{user_request, constraints:[{id,text,type,verify}], requirements:[{id,text,wave}], waves:[{id,name,estimated_hours,tasks:[{id,do,files,verify,ref,priority,type,model,effort}]}]}`

**CONSTRAINT VALIDATION GATE (ADR-054)**: After generating tasks, cross-check EVERY task against EVERY constraint. Present matrix: `| Task | C-01 | C-02 | ... |`. Any cell = VIOLATES → redesign task or BLOCK. Example: if C-01 = "No admin permissions required" and T2-01 = "Configure EasyAuth (requires admin consent)" → VIOLATION → remove or redesign T2-01.

**Rules**: `do`=ONE action. `files`=explicit paths. `verify`=machine-checkable. `ref`=F-xx ID. Missing `verify`=broken. **Per-wave docs**: TX-doc (CHANGELOG + plan-{id}-notes.md). **Final wave** "WF-Closure": TF-01 (notes->ADRs), TF-02 (CHANGELOG), TF-03 (ESLint), TF-tests (test consolidation), TF-pr (PR+CI). Cite ADRs in `do`.

### 2.1 Schema Validation (MANDATORY)

Validate spec.json before import. Source: [HVE Core](https://github.com/microsoft/hve-core) schema-driven validation pattern.

```bash
python3 -c "
import json, sys
try:
    from jsonschema import validate, ValidationError
    schema = json.load(open('$HOME/.claude/config/plan-spec-schema.json'))
    spec = json.load(open('/path/to/spec.json'))
    validate(spec, schema)
    print('PASS: spec.json valid')
except ValidationError as e:
    print(f'FAIL: {e.message}'); sys.exit(1)
except ImportError:
    # Fallback: basic structural check without jsonschema
    spec = json.load(open('/path/to/spec.json'))
    for field in ['user_request', 'requirements', 'waves']:
        assert field in spec, f'Missing: {field}'
    for w in spec['waves']:
        for t in w['tasks']:
            assert t.get('verify'), f'Task {t[\"id\"]} missing verify'
    print('PASS: spec.json structurally valid (no jsonschema)')
"
```

**BLOCK if validation fails.** Fix spec errors before proceeding. Common failures: missing `verify` array, invalid task ID pattern, effort outside 1-3 range.

### 2.5 Copilot-First Delegation (MANDATORY — Rule 13) {#step-2-5}

**ALL tasks default to `executor_agent: "copilot"`.** Only escalate to `claude` per decision tree in @planner-modules/model-strategy.md. Present summary: "Task su Claude (pagati): [list + perche']. Tutto il resto su Copilot (gratis). Ok?"

**Copilot model assignment**: trivial -> `gpt-5.1-codex-mini` | standard -> `gpt-5.3-codex` | complex -> `claude-opus-4.6-fast`. See model-strategy for full tree.

**Never delegate to Copilot**: architecture decisions, security-sensitive, investigative debugging, cross-system integration where failure cascades.

**Exec**: `copilot-worker.sh <id> --model <model> --timeout 600`. Requires: `copilot --yolo`, `GH_TOKEN`.

### 2.7 Cross-Plan Conflict Check (MANDATORY)

```bash
CONFLICT_REPORT=$(plan-db.sh conflict-check-spec $PROJECT_ID /path/to/spec.json)
RISK=$(echo "$CONFLICT_REPORT" | jq -r '.overall_risk')
```

If risk != "none", AskUserQuestion: Merge | Sequence | Parallel | Abort. If risk == "none", proceed silently.

### 3. Create Plan + Import

```bash
PROMPT_FILE=".copilot-tracking/prompt-{NNN}.json"
PLAN_ID=$(plan-db.sh create $PROJECT_ID "{PlanName}" --source-file "$PROMPT_FILE" \
  --human-summary "2-3 righe in italiano che spiegano COSA fa il piano per un umano. Mostrato in dashboard.")
# Note: --auto-worktree is deprecated; use wave-level worktrees instead
plan-db.sh import $PLAN_ID /path/to/spec.json
WORKTREE_PATH=$(plan-db.sh get-worktree $PLAN_ID)
cd "$WORKTREE_PATH"
```

**`--human-summary` MANDATORY**: Riassunto leggibile del piano (NO path, NO istruzioni agente, NO workflow). Max 200 chars. Esempio: "Rinomina deployment Azure OpenAI da gpt-4o-realtime a gpt-realtime in tutti i file di configurazione e secrets"

### 3.1 Plan Intelligence Review (MANDATORY — Rule 14) {#step-3-1}

**MANDATORY for plans with 3+ tasks.** Skip ONLY for 1-2 task plans (trivial scope). Skipping on 3+ tasks = VIOLATION.

Launch plan-reviewer + plan-business-advisor in parallel. Both receive spec file path and plan_id.

**Claude Code:**

```
# Launch BOTH in parallel
review_result = await Task(subagent_type="plan-reviewer", prompt="PLAN_ID=$PLAN_ID SPEC=/path/to/spec.json")
biz_result = await Task(subagent_type="plan-business-advisor", prompt="PLAN_ID=$PLAN_ID SPEC=/path/to/spec.json")
```

**Copilot CLI:**

```bash
# Two @agent invocations (parallel)
@plan-reviewer PLAN_ID=$PLAN_ID SPEC=/path/to/spec.json
@plan-business-advisor PLAN_ID=$PLAN_ID SPEC=/path/to/spec.json
```

Store results:

```bash
plan-db.sh add-review $PLAN_ID "$REVIEW_JSON"
plan-db.sh add-assessment $PLAN_ID "$ASSESSMENT_JSON"
```

### 3.2 Present Intelligence Summary

Display alongside plan summary:

| Metric                    | Source                | Action if Red           |
| ------------------------- | --------------------- | ----------------------- |
| `fxx_coverage_score`      | plan-reviewer         | Fix gaps before approve |
| `completeness_score`      | plan-reviewer         | Add missing verify/refs |
| `traditional_effort_days` | plan-business-advisor | Inform user of baseline |
| `roi_projection`          | plan-business-advisor | Flag if ROI < 2x        |

Format: "📊 **Review**: coverage={score}%, completeness={score}% | **Business**: {days}d traditional, ROI {x}x"

### 4. User Approval (MANDATORY STOP)

Present F-xx + Codex proposals + review verdict + business assessment. "si"/"yes" -> Proceed. If review flagged critical gaps, list them explicitly before approval gate.

### 5. Parallelization Mode

See @planner-modules/parallelization-modes.md. AskUserQuestion: Standard (3) vs Max (unlimited, Opus).

### 5.5 Pre-Execution Token Estimates

Before execution starts, populate token estimates for all tasks:

```bash
token-estimator.sh estimate $PLAN_ID /path/to/spec.json
```

Writes per-task estimates to `plan_token_estimates` table. Used by post-mortem for variance analysis.

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

### 8c. Wave Merge (automatic)

After Thor per-wave validation, `plan-db-safe.sh` auto-triggers:

1. `wave-worktree.sh merge` → commit + push + PR + CI + merge
2. Wave status: `in_progress` → `merging` → `done`
3. Next wave creates fresh worktree from updated main

Manual: `wave-worktree.sh merge <plan_id> <wave_db_id>`
Status: `wave-worktree.sh status <plan_id>`

### 9. Knowledge Codification

See @planner-modules/knowledge-codification.md. LEARNINGS LOG -> ADRs -> ESLint -> Thor validates.

## 10. Completion + Post-Mortem {#completion}

After `plan-db.sh complete $PLAN_ID`:

```bash
# 1. Reconcile token actuals vs estimates
token-estimator.sh reconcile $PLAN_ID

# 2. Trigger post-mortem agent (populates plan_learnings + plan_actuals)
# Claude Code:
await Task(subagent_type="plan-post-mortem", prompt="PLAN_ID=$PLAN_ID")
# Copilot CLI:
@plan-post-mortem PLAN_ID=$PLAN_ID
```

Post-mortem auto-writes: `plan_learnings` (what went well/badly, reusable patterns), `plan_actuals` (real tokens, durations, retry counts). Data feeds Step 1.5 intelligence queries for future plans.

## 10.1 Failed Approaches Tracking {#failed-approaches}

Task fails max retries → executor logs: `plan-db.sh log-failure $PLAN_ID $TASK_ID "approach" "reason"`. Planner reads at step 1.5: `plan-db.sh get-failures $PROJECT_ID`. Same approach failed before = MUST use different strategy. Failures are project-scoped, persist across plans.

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

## Cross-Tool Execution & State

Cross-tool: Executing tool gets `T0-00 Review Plan` first (see @planner-modules/model-strategy.md). spec.json = handoff contract. States: `pending -> in_progress -> done|blocked|skipped`. Forbidden: `done -> pending`, `skipped -> done`.
