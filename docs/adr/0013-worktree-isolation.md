# ADR 0013: Worktree Isolation Protocol

**Status**: Accepted
**Date**: 21 Feb 2026
**Plan**: 189

## Context

Multi-agent plan execution requires isolated workspaces to prevent:

- **Merge conflicts**: Multiple agents editing same files on main branch
- **State corruption**: Agent A's changes affecting Agent B's execution
- **Data loss**: Uncompleted plans leaving main branch in broken state
- **Review friction**: Cannot review plan changes as single atomic PR

Traditional approaches (feature branches + checkouts on main) fail because:
- `git checkout` on main repository risks switching away from uncommitted work
- Multiple agents cannot work concurrently on same repository
- No clear boundary between "plan workspace" and "main codebase"

Git worktrees solve this: each plan gets independent working directory with own branch, all sharing same .git object database.

## Decision

### Core Protocol

| Rule | Enforcement | Consequence |
|------|-------------|-------------|
| **One worktree per plan** | worktree-create.sh generates unique path `~/.claude-plan-{id}/` | Isolated filesystem prevents cross-plan interference |
| **git checkout FORBIDDEN on main** | worktree-guard.sh blocks execution if `pwd` == main repo | Protects main from accidental switches |
| **Branch naming**: `plan/{id}-{slug}` | worktree-create.sh enforces convention | Easy identification in `git branch -a` |
| **Cleanup after merge** | git worktree remove after PR merged | No orphaned directories |

### Worktree Lifecycle

```
1. CREATE:  worktree-create.sh --plan-id 189 --name "feature-xyz"
            → ~/.claude-plan-189/ + branch plan/189-feature-xyz
            
2. WORK:    cd ~/.claude-plan-189/ && plan-executor.sh
            → All changes isolated to worktree
            
3. REVIEW:  git push origin plan/189-feature-xyz → GitHub PR
            → Review entire plan as single changeset
            
4. MERGE:   GitHub PR merged to main
            
5. CLEANUP: git worktree remove ~/.claude-plan-189/
            → Reclaim disk space
```

### Isolation Benefits

| Benefit | Mechanism |
|---------|-----------|
| **Concurrent execution** | 3 agents can work on plans 189, 190, 191 simultaneously |
| **Atomic commits** | Each plan's commits grouped on feature branch |
| **Rollback safety** | Abandon worktree without affecting main |
| **Review clarity** | PR shows exactly what plan changed |
| **No stashing** | No need to stash/pop when switching contexts |

### worktree-guard.sh Logic

```bash
#!/usr/bin/env bash
# Blocks execution if in main repository

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
WORKTREE_PATH="$1"

if [[ "$PWD" == "$REPO_ROOT" ]] && [[ "$WORKTREE_PATH" != "$REPO_ROOT" ]]; then
  echo "WORKTREE_VIOLATION: Must run from worktree, not main repo"
  echo "Expected: cd $WORKTREE_PATH"
  exit 1
fi

echo "WORKTREE_OK: $(git branch --show-current) @ $PWD"
```

### Storage Layout

```
~/.claude/                    # Main repository
  ├── .git/                   # Shared object database
  ├── scripts/
  └── ...

~/.claude-plan-189/          # Plan 189 worktree
  ├── .git → ~/.claude/.git/worktrees/plan-189/
  ├── scripts/               # Same tree, different branch
  └── ...

~/.claude-plan-190/          # Plan 190 worktree (concurrent)
  ├── .git → ~/.claude/.git/worktrees/plan-190/
  └── ...
```

All worktrees share same `.git/objects/` (disk efficient), but have independent:
- Working directory (files on disk)
- HEAD (current commit)
- Index (staging area)

## Consequences

### Positive
- **Zero merge conflicts** between concurrent plans
- **Safe experimentation**: Worktree deletion = instant rollback
- **Clear boundaries**: Filesystem path indicates plan context
- **PR hygiene**: Each plan = one PR with focused changes
- **Disk efficiency**: Shared object database (only ~5MB overhead per worktree)

### Negative
- **Learning curve**: Team must understand worktree concept vs. branches
- **Disk usage**: N concurrent plans = N working directories (~50MB each for full checkout)
- **Cleanup discipline**: Orphaned worktrees consume disk if not removed
- **Path length**: Long worktree paths (~40 chars) visible in shell prompts

### Migration from Branch-Based Workflow

| Old Workflow | New Workflow |
|--------------|--------------|
| `git checkout -b feature-x` | `worktree-create.sh --name feature-x` |
| `git checkout main` | `cd ~/.claude/` (main repo) |
| `git branch -D feature-x` | `git worktree remove ~/.claude-plan-189/` |
| Work in `~/.claude/` | Work in `~/.claude-plan-189/` |

## File Impact Table

| File | Purpose/Impact |
|------|----------------|
| scripts/worktree-create.sh | Create plan worktree with naming convention |
| scripts/worktree-guard.sh | Block execution on main repository |
| scripts/plan-executor.sh | Enforce worktree-guard.sh before task execution |
| scripts/plan-db.sh | Store worktree_path in plans table |
| db/schema.sql | plans.worktree_path column (TEXT) |
| agents/plan-executor.md | Document worktree workflow |

## References

- Git documentation: `git help worktree`
- ADR 0004: Distributed Plan Execution (multi-agent concurrency)
- ADR 0005: Multi-Agent Concurrency Control (lock table)
- PLANNER-ARCHITECTURE.md: Worktree isolation section
