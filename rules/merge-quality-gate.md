<!-- v1.0.0 -->

# Merge Quality Gate (NON-NEGOTIABLE)

Every merge to main MUST pass ALL gates. No `--admin` bypass, no "CI will catch it".

## Pre-Merge Checklist

| # | Gate | Command | BLOCK if |
|---|---|---|---|
| 1 | Clean working tree | `git status --short` | Any modified/untracked project files |
| 2 | No cross-feature contamination | `git diff --name-only` vs task file list | Files outside PR scope present |
| 3 | Type-check (if frontend) | `npx tsc --noEmit -p tsconfig.app.json` | Exit code != 0 |
| 4 | Tests pass | `pytest -m "not integration"` / `vitest` | Exit code != 0 |
| 5 | Lint clean | `ruff check` / `eslint` | Errors (warnings OK) |
| 6 | Version synced | VERSION.md matches pyproject.toml/package.json | Mismatch |
| 7 | CHANGELOG updated | Latest entry matches current version | Stale |
| 8 | No orphan stashes | `git stash list` from this session | Stashes not cleaned |

## Enforcement

Hook `pre-merge-gate.sh` runs gates 1-5 automatically before `git push` on PR branches.

## Cross-Feature Contamination Detection

When a branch has unstaged files from other features:
1. `git diff --name-only` lists ALL modified files (staged + unstaged)
2. Compare against PR's intended scope (from task spec or commit messages)
3. Files outside scope = contamination → must be resolved BEFORE push:
   - `git checkout -- <file>` to discard if not needed
   - `git stash push -m "other-feature" -- <files>` to save for later
   - NEVER commit contaminating files into the PR

## Post-Merge Cleanup (MANDATORY)

After squash merge to main:
1. `git checkout main && git pull`
2. Delete feature branch: `git branch -d feat/xxx`
3. `git stash list` — drop session stashes
4. `git worktree list` — only main worktree should remain
5. Verify: `git status --short` = clean

_Why: Plan v21 — 37 unstaged files from gantt/detail-panel/auth contaminated exec-reporting branch. Workflow-proof hook blocked 3 commits. Half-day lost to manual cleanup._
