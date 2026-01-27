# Worktree Discipline (MANDATORY for multi-worktree)

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
- **Symlinks all .env* files** from main repo (no missing configs!)
- Runs npm install if package.json exists

## Before ANY git operation (commit, push, add, checkout):

```bash
~/.claude/scripts/worktree-check.sh [expected-worktree]  # Verify context first!
```

## Rules

1. **Create via script**: Never `git worktree add` directly - use `worktree-create.sh`
2. **.env = symlinks**: All worktrees share .env from main repo via symlinks
3. **Know where you are**: Check pwd and branch before git operations
4. **One worktree = one task**: Don't switch between worktrees mid-task
5. **Clean before switch**: Commit or stash before changing worktree
6. **Hook protection**: `worktree-guard.sh` warns on multi-worktree git ops

**If confused**: Run `worktree-check.sh` to see full context.
