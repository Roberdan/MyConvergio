<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Worktree Discipline

## Plan = Worktree (ENFORCED)

Every plan gets dedicated worktree. Planner auto-creates:

```bash
# Auto: plan/{plan_id}-{slug} branch + worktree directory
# Path stored in DB: plan-db.sh get-worktree {plan_id}
# Executor reads from DB, NEVER from pwd
```

**worktree-guard.sh BLOCKS git write ops on main/master** when worktrees exist (exit 2).

## Creating Worktrees

**ALWAYS use script** (never raw `git worktree add`):

```bash
worktree-create.sh <branch> [path]
# Examples:
worktree-create.sh feature/api-v2              # Auto-path: ../repo-api-v2
worktree-create.sh fix/bug-123 ../myfix        # Custom path
```

Script auto: creates worktree, symlinks all `.env*` files, runs `npm install` if `package.json` exists.

## Before ANY git operation

```bash
worktree-check.sh [expected-worktree]  # Verify context first
```

## Rules

1. **Create via script**: Never `git worktree add` directly — use `worktree-create.sh`
2. **One plan = one worktree**: Planner creates, executor uses, path in DB
3. **.env = symlinks**: All worktrees share .env from main repo
4. **Know where you are**: Check pwd and branch before git operations
5. **Clean before switch**: Commit or stash before changing worktree
6. **Hook BLOCKS on main**: `worktree-guard.sh` blocks git write ops on main/master
7. **DB is source of truth**: `plan-db.sh get-worktree {plan_id}` for path
8. **check-readiness validates**: Missing worktree_path = execution blocked

## DB Commands

```bash
plan-db.sh set-worktree <plan_id> <path>  # Store
plan-db.sh get-worktree <plan_id>         # Retrieve
plan-db.sh check-readiness <plan_id>      # Validate worktree_path is set
```

If confused: run `worktree-check.sh` to see full context.

## node_modules in Worktrees

Next.js/Turbopack builds **FAIL** with symlinked node_modules.

### Option A: Full install (RECOMMENDED for builds)

```bash
cd /path/to/worktree && npm ci --silent
```

### Option B: TypeScript-only (faster dev)

Symlink works for tsc, NOT for builds:

```bash
ln -s /path/to/main/repo/node_modules /path/to/worktree/node_modules
npx tsc --noEmit  # Works
npm run build     # FAILS (Sentry/Turbopack path issues)
```

### Option C: Verify in main after merge

```bash
cd /path/to/main/repo
git merge worktree-branch
npm run ci:summary
```

### Why symlinks fail

Turbopack resolves absolute paths; Sentry plugin follows symlinks; motion-utils has hardcoded path expectations.

**Best practice**: Symlink for fast TypeScript checks during dev; run full build verification in main repo after merge.
