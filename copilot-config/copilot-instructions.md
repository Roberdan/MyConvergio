# Copilot CLI — Global Instructions

**For shared standards, rules, and workflow, see AGENTS.md and CLAUDE.md**

This file contains ONLY Copilot CLI-specific configurations: model routing and orchestration agents.

## Model Strategy (18 models available)

Select the optimal model based on task type. Override via `model:` parameter in task tool.

### Model Routing Table

| Use Case                       | Model                | Tier     |
| ------------------------------ | -------------------- | -------- |
| **Requirements extraction**    | `claude-opus-4.6`    | premium  |
| **Strategic planning**         | `claude-opus-4.6-1m` | premium  |
| **Code generation / TDD**      | `gpt-5.3-codex`      | standard |
| **Quality validation (Thor)**  | `claude-sonnet-4.6`  | standard |
| **Code review / security**     | `claude-opus-4.6`    | premium  |
| **Compliance (full codebase)** | `claude-opus-4.6-1m` | premium  |
| **Documentation writing**      | `claude-sonnet-4.5`  | standard |
| **Codebase exploration**       | `claude-haiku-4.5`   | fast     |
| **Quick fixes / bulk edits**   | `gpt-5-mini`         | fast     |
| **Build / test execution**     | `claude-haiku-4.5`   | fast     |
| **Complex refactoring**        | `gpt-5.3-codex`      | standard |
| **Architecture analysis**      | `claude-opus-4.6-1m` | premium  |

### When to Use 1M Context (`claude-opus-4.6-1m`)

- Planning across an entire large codebase (>100 files)
- Compliance audit reading all docs + source
- Architecture review of full project
- Migration planning needing full dependency graph

### When to Use GPT-5.3-Codex (`gpt-5.3-codex`)

- Writing new code (functions, classes, modules)
- TDD cycles (test writing + implementation)
- Refactoring with clear patterns
- Mechanical transformations across files

### When to Use Opus (`claude-opus-4.6`)

- Security analysis requiring deep reasoning
- Requirement extraction catching edge cases
- Thor validation gates (zero tolerance mode)
- Complex design decisions

## Orchestration Agents

| Agent                 | Purpose                   | Default Model        |
| --------------------- | ------------------------- | -------------------- |
| `@prompt`             | Extract F-xx requirements | `claude-opus-4.6`    |
| `@planner`            | Wave/task decomposition   | `claude-opus-4.6-1m` |
| `@execute`            | TDD task execution        | `gpt-5.3-codex`      |
| `@validate`           | Thor quality gates        | `claude-opus-4.6`    |
| `@strategic-planner`  | Multi-phase initiatives   | `claude-opus-4.6-1m` |
| `@code-reviewer`      | Security-focused review   | `claude-opus-4.6`    |
| `@tdd-executor`       | Standalone TDD cycle      | `gpt-5.3-codex`      |
| `@compliance-checker` | Regulatory validation     | `claude-opus-4.6-1m` |

## Practical Planner Entry Points

Copilot CLI does **not** expose a custom `/planner` slash command.

| Need | Copilot CLI entry point |
| ---- | ------------------------ |
| Interactive session | `/agent` → select `planner` |
| One-shot shell launch | `cplanner "your goal"` |
| Pasteable fallback | `@planner` followed by the goal |
| Avoid | `/plan` — built-in lightweight planner, **not** our plan-db planner |

## `/execute` — Plan Execution Workflow (MANDATORY)

When the user says `/execute {plan_id}` or `@execute {plan_id}`:

### Step-by-step

```bash
export PATH="$HOME/.claude/scripts:$PATH"
PLAN_ID={plan_id}

# 1. Initialize
CTX=$(plan-db.sh get-context $PLAN_ID)
# Extract WORKTREE_PATH, FRAMEWORK, pending tasks from CTX
cd "$WORKTREE_PATH"

# 2. Start plan + guards
plan-db.sh start $PLAN_ID
worktree-guard.sh "$WORKTREE_PATH"
plan-db.sh drift-check $PLAN_ID

# 3. For EACH pending task — DIRECT inline execution
#    (copilot-worker.sh is for BACKGROUND delegation only)
```

### Per-Task Protocol (7 steps — NEVER skip)

```bash
# STEP 0: Environment preflight (MANDATORY before first task)
cd "$WORKTREE_PATH"
git fetch origin && git pull --rebase origin $(git branch --show-current) 2>/dev/null || true
git status --short  # must be clean or stash first
# Verify dependencies: npm ci / pip install / etc (if package.json/requirements.txt changed)

# STEP 1: Mark started
plan-db.sh update-task ${db_id} in_progress "Started"

# STEP 2: Do the work (inline edit/create/test in worktree)
# TDD: write failing test → implement → pass

# STEP 3: Verify (unit tests + typecheck)
cd "$WORKTREE_PATH" && npm run test:unit -- --reporter=dot
# Run task-specific verify commands from test_criteria

# STEP 4: Submit (proof-of-work gates)
plan-db-safe.sh update-task ${db_id} done "Summary" \
  --output-data '{"summary":"...","artifacts":["file1","file2"]}'
# plan-db-safe.sh runs Guard 1 (time), Guard 2 (git-diff), Guard 3 (verify commands)
# Sets status to "submitted" (NEVER done directly)

# STEP 5: Thor validation
# Option A — claude CLI available (preferred, independent validator):
#   claude --model sonnet -p "Thor per-task: verify task ${task_id}..." \
#     && plan-db.sh validate-task ${db_id} ${PLAN_ID} thor
# Option B — self-validation (Copilot CLI acts as Thor):
#   Re-read modified files, verify quality, check constraints
plan-db.sh validate-task ${db_id} ${PLAN_ID} thor
# SQLite trigger enforces: only submitted→done with valid validator

# STEP 6: Confirm
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT status, validated_at FROM tasks WHERE id=${db_id};"
# Must show: status=done, validated_at NOT NULL
```

### Self-Validation Protocol (when acting as Thor)

Before calling `validate-task`, verify ALL of:

1. **Files exist**: `test -f` for each expected artifact
2. **Verify commands**: run ALL commands from `test_criteria.verify[]`
3. **Tests pass**: `npm run test:unit -- {relevant_files} --reporter=dot`
4. **Typecheck**: `npm run typecheck` (or targeted check)
5. **Constraints**: check plan constraints (C-01..C-xx)
6. **Line limits**: `wc -l` on modified files (max 250)

If ANY check fails → fix first, re-submit, re-validate. Max 3 rounds.

### Wave Completion

```bash
# After ALL tasks in wave are done:
plan-db.sh validate-wave ${wave_db_id}

# If wave has a PR: WAIT for CI to pass before completing
# gh pr checks {pr_number} --watch --fail-fast
# If CI fails → fix, push, wait again. PR not merged = wave not done.

# After ALL waves: complete plan
plan-db.sh sync $PLAN_ID
plan-db.sh complete $PLAN_ID
```

### CI Gate (NON-NEGOTIABLE)

A wave/plan is **NOT done** until CI passes on its PR. Steps:
1. Push branch, create PR
2. `gh pr checks {pr_number} --watch` — wait for all checks
3. If CI fails → read logs (`gh run view --log-failed`), fix, push, re-check
4. Only after CI green → `plan-db.sh validate-wave` → merge PR
5. A plan with a failing PR is **blocked**, not done

### When to use copilot-worker.sh (BACKGROUND only)

Use `copilot-worker.sh` ONLY for fire-and-forget background delegation:

```bash
# Parallel low-risk tasks while you work on something else
copilot-worker.sh ${db_id} --model gpt-5-mini --timeout 300 &
```

NEVER use it as the primary execution method — it spawns a sub-copilot, doubles token cost, and blocks the orchestrator.

## Anti-Bypass Protection (CRITICAL)

**Plan creation**: NEVER create plans inline. ALWAYS use `@planner`. _Why: Plan 225._

**Enforcement**: No `plan_id` in DB = `@execute` BLOCKED. `plan-db.sh check-readiness` validates.

**Status chain**: pending → in_progress → submitted (plan-db-safe.sh) → done (validate-task ONLY). SQLite trigger `enforce_thor_done` blocks shortcuts.

### Mandatory Routing

| Trigger                    | Copilot CLI                               | NOT                            |
| -------------------------- | ----------------------------------------- | ------------------------------ |
| Multi-step work (3+ tasks) | `@planner`                                | Inline plan text               |
| Execute plan tasks         | `@execute {id}`                           | —                              |
| Thor validation            | `@validate` handoff (NEVER self-validate) | Skipping / self-declaring done |
| Single isolated fix        | Direct edit                               | Creating unnecessary plan      |

**PLANNER MODEL (NON-NEGOTIABLE)**: `@planner` DEVE sempre girare su `claude-opus-4.6-1m`. Modelli inferiori per la pianificazione = VIOLATION (vedi Plan 289, cancellato perché pianificato da Sonnet).

## Digest Scripts (NON-NEGOTIABLE)

**NEVER run verbose commands directly.** Use digest scripts — compact JSON, cached.

```bash
export PATH="$HOME/.claude/scripts:$PATH"
```

| Instead of                 | Use                          |
| -------------------------- | ---------------------------- |
| `gh run view --log-failed` | `service-digest.sh ci`       |
| `gh pr view --comments`    | `service-digest.sh pr`       |
| `npm install` / `npm ci`   | `npm-digest.sh install`      |
| `npm run build`            | `build-digest.sh`            |
| `npm audit`                | `audit-digest.sh`            |
| `npx vitest` / `npm test`  | `test-digest.sh`             |
| `git diff main...feat`     | `diff-digest.sh main feat`   |
| `git status` / `git log`   | `git-digest.sh [--full]`     |
| `npx prisma migrate`       | `migration-digest.sh status` |
| Copilot bot PR comments    | `copilot-review-digest.sh`   |
| Pattern check (pre-PR)     | `code-pattern-check.sh`      |

## Token-Aware Writing (MANDATORY)

Every token costs money. Applies to ALL agent output: code, commits, PRs, reviews, docs, ADRs, changelogs, agent .md. **Exception**: README stays human-friendly.

- **Code comments**: <5% lines. Only WHY, never WHAT.
- **Commits**: conventional, 1 subject line. No filler.
- **PRs**: `## Summary` (2-3 bullets) + `## Test plan`.
- **Reviews**: issue + fix. No softening.
- **Docs/ADRs/CHANGELOGs**: tables > prose, commands > descriptions. No preambles.

## Background Delegation

Prefix any prompt with `&` to delegate to a cloud coding agent running in the background:

```
& refactor all fetch calls to use the new API client
```

Use `/resume` to check status or retrieve output. Useful for long-running mechanical tasks (bulk refactoring, file generation, migration scripts) where you don't need to wait inline.

## Session Tools

| Command              | Purpose                                             |
| -------------------- | --------------------------------------------------- |
| `/chronicle standup` | Auto-generate standup from session history          |
| `/chronicle tips`    | Optimization tips based on current session patterns |

**Cross-session memory**: Copilot retains context between sessions (Pro/Pro+ plans). Reference earlier decisions without re-explaining.

## .github/skills/ Support

Skills in `.github/skills/` are auto-loaded by Copilot CLI when relevant to the current task. Mirror key skills from `.claude/skills/` for cross-tool parity (same skill, both paths).

## Plan DB Commands

```bash
plan-db.sh create {project} "Name" --source-file {prompt.md} --auto-worktree
plan-db.sh import {plan_id} spec.json
plan-db-safe.sh update-task {id} done "Summary"  # ALWAYS use safe for done (auto-validates)
plan-db.sh validate {id}
plan-db.sh list-tasks {plan_id}
git-digest.sh --full
```
