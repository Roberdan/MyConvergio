<!-- v3.2.0 | 27 Feb 2026 | Rebase-before-merge, no forward-merge rule -->

# Worktree Discipline

## Wave-per-Worktree Model (v2) — Default

Every wave gets a dedicated worktree + PR. Merge is proof that work exists.

### Lifecycle

```
create → execute tasks → Thor validate → rebase → PR → squash merge → cleanup
```

1. `wave-worktree.sh create <plan_id> <wave_db_id>` — worktree from main HEAD
2. Task executors work in wave worktree
3. Thor per-task + per-wave validation
4. `wave-worktree.sh merge` — rebase onto main, push, PR, CI, squash merge
5. Wave status: `pending` → `in_progress` → `merging` → `done`
6. `done` = ONLY after merge to main succeeds

### Git Graph Hygiene (NON-NEGOTIABLE)

**NEVER `git merge main` into a wave branch.** This creates merge commits that pollute the git graph.

| Need to sync with main? | Do this                         | NOT this         |
| ----------------------- | ------------------------------- | ---------------- |
| During task execution   | `git rebase origin/main`        | `git merge main` |
| Before push             | `wave-worktree.sh merge` (auto) | Manual merge     |
| Conflicts               | Rebase + resolve                | Forward-merge    |

`wave-worktree.sh merge` v2.1.0 auto-rebases onto main before push (`--force-with-lease`).

### Branch Naming

`plan/{plan_id}-{wave_id}` — e.g., `plan/200-W1`

### DB Columns (waves table)

| Column        | Type    | Purpose               |
| ------------- | ------- | --------------------- |
| worktree_path | TEXT    | Path to wave worktree |
| branch_name   | TEXT    | Git branch name       |
| pr_number     | INTEGER | PR number             |
| pr_url        | TEXT    | PR URL                |

### Commands

```bash
wave-worktree.sh create <plan_id> <wave_db_id>   # Create wave worktree
wave-worktree.sh merge <plan_id> <wave_db_id>     # Commit + PR + merge + cleanup
wave-worktree.sh cleanup <plan_id> <wave_db_id>   # Remove worktree (manual)
wave-worktree.sh status <plan_id>                  # Table of all waves
plan-db.sh get-wave-worktree <wave_db_id>         # Get wave worktree path
plan-db.sh set-wave-worktree <wave_db_id> <path>  # Set wave worktree path
dashboard-mini.sh waves <plan_id>                  # Dashboard wave view
```

### Backward Compatibility

Old plans with `plans.worktree_path` work unchanged. `wave_is_active(plan_id)` distinguishes models.

---

## Native Subagent Worktree Isolation (v2.1.50+)

Per-task isolation via Task tool parameter — no wave-worktree overhead required.

### How It Works

```json
{
  "type": "Task",
  "subagent_type": "task-executor",
  "isolation": "worktree"
}
```

- Task tool creates a temporary git worktree automatically before subagent starts
- Subagent works in isolation; no risk of cross-task file conflicts
- On completion: if no changes → worktree cleaned up silently
- If changes made → branch returned to coordinator for review/merge

### Hook Lifecycle

| Hook           | Trigger                 | Default Action                                           |
| -------------- | ----------------------- | -------------------------------------------------------- |
| WorktreeCreate | After worktree creation | Auto symlink `.env*` files; run `npm install` if present |
| WorktreeRemove | Before worktree removal | Cleanup temp files; release file locks for task          |

### When to Use

- Per-task isolation without full wave-worktree lifecycle
- Short-lived tasks where PR overhead is unnecessary
- Parallel tasks touching disjoint files within same wave

### Relationship to Wave-per-Worktree (v2)

Native isolation is a **per-task enhancement**, NOT a replacement for wave-worktree:

- Wave-per-Worktree v2 remains the **primary model** (PR + CI + merge = proof of work)
- Native isolation is complementary: use inside a wave for finer-grained task isolation
- Both can coexist; coordinator chooses per task based on scope

---

## Legacy: Plan-per-Worktree Model (v1)

### Plan = Worktree (ENFORCED)

Every plan gets dedicated worktree. Planner auto-creates:

```bash
# Auto: plan/{plan_id}-{slug} branch + worktree directory
# Path stored in DB: plan-db.sh get-worktree {plan_id}
# Executor reads from DB, NEVER from pwd
```

**worktree-guard.sh BLOCKS git write ops on main/master** when worktrees exist (exit 2).

### Creating Worktrees

**ALWAYS use script** (never raw `git worktree add`):

```bash
worktree-create.sh <branch> [path]
# Examples:
worktree-create.sh feature/api-v2              # Auto-path: ../repo-api-v2
worktree-create.sh fix/bug-123 ../myfix        # Custom path
```

Script auto: creates worktree, symlinks all `.env*` files, runs `npm install` if `package.json` exists.

### Before ANY git operation

```bash
worktree-check.sh [expected-worktree]  # Verify context first
```

### Rules

1. **Create via script**: Never `git worktree add` directly — use `worktree-create.sh`
2. **One plan = one worktree**: Planner creates, executor uses, path in DB
3. **.env = symlinks**: All worktrees share .env from main repo
4. **Know where you are**: Check pwd and branch before git operations
5. **Clean before switch**: Commit or stash before changing worktree
6. **Hook BLOCKS on main**: `worktree-guard.sh` blocks git write ops on main/master
7. **DB is source of truth**: `plan-db.sh get-worktree {plan_id}` for path
8. **check-readiness validates**: Missing worktree_path = execution blocked

### DB Commands

```bash
plan-db.sh set-worktree <plan_id> <path>  # Store
plan-db.sh get-worktree <plan_id>         # Retrieve
plan-db.sh check-readiness <plan_id>      # Validate worktree_path is set
```

If confused: run `worktree-check.sh` to see full context.

### node_modules in Worktrees

Next.js/Turbopack builds **FAIL** with symlinked node_modules.

#### Option A: Full install (RECOMMENDED for builds)

```bash
cd /path/to/worktree && npm ci --silent
```

#### Option B: TypeScript-only (faster dev)

Symlink works for tsc, NOT for builds:

```bash
ln -s /path/to/main/repo/node_modules /path/to/worktree/node_modules
npx tsc --noEmit  # Works
npm run build     # FAILS (Sentry/Turbopack path issues)
```

#### Option C: Verify in main after merge

```bash
cd /path/to/main/repo
git merge worktree-branch
npm run ci:summary
```

#### Why symlinks fail

Turbopack resolves absolute paths; Sentry plugin follows symlinks; motion-utils has hardcoded path expectations.

**Best practice**: Symlink for fast TypeScript checks during dev; run full build verification in main repo after merge.
