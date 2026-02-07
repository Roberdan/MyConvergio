# Worktree Discipline (MANDATORY for multi-worktree)

## Plan = Worktree (ENFORCED)

Every plan gets a dedicated worktree. The planner creates it automatically:

```bash
# Planner auto-creates: plan/{plan_id}-{slug} branch + worktree directory
# Path stored in DB: plan-db.sh get-worktree {plan_id}
# Executor reads from DB, NEVER from pwd
```

**worktree-guard.sh BLOCKS git write ops on main/master** when worktrees exist (exit 2).

## Creating Worktrees

**ALWAYS use the script** (never raw `git worktree add`):

```bash
~/.claude/scripts/worktree-create.sh <branch> [path]
# Examples:
worktree-create.sh feature/api-v2              # Auto-path: ../repo-api-v2
worktree-create.sh fix/bug-123 ../myfix        # Custom path
```

The script automatically:

- Creates worktree with proper branch
- **Symlinks all .env\* files** from main repo (no missing configs!)
- Runs npm install if package.json exists

## Before ANY git operation (commit, push, add, checkout):

```bash
~/.claude/scripts/worktree-check.sh [expected-worktree]  # Verify context first!
```

## Rules

1. **Create via script**: Never `git worktree add` directly - use `worktree-create.sh`
2. **One plan = one worktree**: Planner creates, executor uses, path in DB
3. **.env = symlinks**: All worktrees share .env from main repo via symlinks
4. **Know where you are**: Check pwd and branch before git operations
5. **Clean before switch**: Commit or stash before changing worktree
6. **Hook BLOCKS on main**: `worktree-guard.sh` blocks git write ops on main/master
7. **DB is source of truth**: `plan-db.sh get-worktree {plan_id}` for the path
8. **check-readiness validates**: Missing worktree_path = execution blocked

## Worktree DB Commands

```bash
plan-db.sh set-worktree <plan_id> <path>  # Store worktree path
plan-db.sh get-worktree <plan_id>         # Retrieve worktree path
plan-db.sh check-readiness <plan_id>      # Validates worktree_path is set
```

**If confused**: Run `worktree-check.sh` to see full context.

## node_modules in Worktrees (IMPORTANT)

Next.js/Turbopack builds **FAIL** with symlinked node_modules. Workarounds:

### Option A: Full install in worktree (RECOMMENDED for builds)

```bash
cd /path/to/worktree
npm ci --silent  # Full install, slower but works
```

### Option B: TypeScript-only checks (faster for development)

Symlink works for tsc but not for full builds:

```bash
ln -s /path/to/main/repo/node_modules /path/to/worktree/node_modules
cd /path/to/worktree
npx tsc --noEmit  # Works
npm run build     # FAILS (Sentry/Turbopack path issues)
```

### Option C: Verify in main repo after merge

If worktree build fails, verify post-merge in main:

```bash
cd /path/to/main/repo
git merge worktree-branch
npm run ci:summary  # Full verification
```

### Why symlinks fail

1. Turbopack (Next.js 15) resolves absolute paths from node_modules
2. Sentry plugin follows symlinks and gets confused by paths
3. motion-utils and other dependencies have hardcoded path expectations

**Best practice**: Use symlink for fast TypeScript checks during development, run full build verification in main repo after merge.
