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
| **Quality validation (Thor)**  | `claude-opus-4.6`    | premium  |
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

## `/execute` — Plan Execution Workflow (MANDATORY)

When the user says `/execute {plan_id}` or `@execute {plan_id}`:

**NEVER execute tasks by editing files directly.** EVERY task MUST go through `copilot-worker.sh`.

### Step-by-step

```bash
export PATH="$HOME/.claude/scripts:$PATH"
PLAN_ID={plan_id}

# 1. Initialize
CTX=$(plan-db.sh get-context $PLAN_ID)
# Extract WORKTREE_PATH, FRAMEWORK, pending tasks from CTX

# 2. Start plan if not already doing
plan-db.sh start $PLAN_ID

# 3. For EACH pending task — delegate to copilot-worker.sh
copilot-worker.sh ${task_db_id} --model gpt-5.3-codex --timeout 600

# 4. After each task: verify DB was updated
verify-task-update.sh ${task_db_id} done
# If FAILED: force recovery
plan-db-safe.sh update-task ${task_db_id} done "Auto-recovered by executor"

# 5. After all tasks in a wave: Thor validation
plan-db.sh validate-wave ${wave_db_id}

# 6. After all waves: complete plan
plan-db.sh sync $PLAN_ID
plan-db.sh complete $PLAN_ID
```

**KEY**: `copilot-worker.sh` handles task prompt generation, DB updates, retries, and auto-completion detection. Always runs in `--yolo` mode for full autonomy. NEVER bypass it by running tasks inline.

### If copilot-worker.sh is unavailable

Fall back to manual task execution but **ALWAYS call plan-db-safe.sh** (not plan-db.sh) for done status:

```bash
# Mark started
plan-db-safe.sh update-task ${task_db_id} in_progress "Started"
# ... do the work ...
# Mark done — MUST use plan-db-safe.sh (plan-db.sh BLOCKS done status)
plan-db-safe.sh update-task ${task_db_id} done "Summary" --tokens 0
```

## Anti-Bypass Protection (CRITICAL)

**Plan creation**: NEVER create plans inline. ALWAYS use `@planner`. Manual plan text = no DB registration = Thor/execute/tracking all break. _Why: Plan 225._

**Task execution**: NEVER edit files directly during active plan. EVERY task through `copilot-worker.sh`. Direct edit = VIOLATION. _Why: Plan 182._

**Enforcement**: No `plan_id` in DB = `@execute` BLOCKED. `plan-db.sh check-readiness` validates.

### Mandatory Routing

| Trigger                    | Copilot CLI     | NOT                       |
| -------------------------- | --------------- | ------------------------- |
| Multi-step work (3+ tasks) | `@planner`      | Inline plan text          |
| Execute plan tasks         | `@execute {id}` | Direct file editing       |
| Thor validation            | `@validate`     | Self-declaring done       |
| Single isolated fix        | Direct edit     | Creating unnecessary plan |

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
