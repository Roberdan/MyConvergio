---
name: strategic-planner-git
description: Git worktree workflow for strategic-planner parallel execution. Reference module.
version: "2.0.0"
maturity: stable
providers:
  - claude
constraints: ["Read-only — never modifies files"]
---

# Git Worktree Workflow (MANDATORY)

**Ogni Claude lavora in un worktree separato. Ogni fase = 1 PR. Zero conflitti.**

## STEP 0: Setup Worktrees

CLAUDE 1 does this BEFORE anything else:

```bash
cd [project_root]

# Create branch for each phase
git checkout [main_branch]
git branch feature/[plan]-phase1
git branch feature/[plan]-phase2
git branch feature/[plan]-phase3

# Create worktree for each Claude
git worktree add ../[project]-C2 feature/[plan]-phase1
git worktree add ../[project]-C3 feature/[plan]-phase2
git worktree add ../[project]-C4 feature/[plan]-phase3

# Verify
git worktree list
```


## Mapping Claude → Worktree → Branch

| Claude | Worktree | Branch | PR |
|--------|----------|--------|-----|
| CLAUDE 1 | `[project_root]` | [main_branch] | Coordina solo |
| CLAUDE 2 | `../[project]-C2` | feature/[plan]-phase1 | PR #1 |
| CLAUDE 3 | `../[project]-C3` | feature/[plan]-phase2 | PR #2 |
| CLAUDE 4 | `../[project]-C4` | feature/[plan]-phase3 | PR #3 |


## Send Claude to Worktrees

```bash
kitty @ send-text --match title:Claude-2 "cd ../[project]-C2" && kitty @ send-key --match title:Claude-2 Return
kitty @ send-text --match title:Claude-3 "cd ../[project]-C3" && kitty @ send-key --match title:Claude-3 Return
kitty @ send-text --match title:Claude-4 "cd ../[project]-C4" && kitty @ send-key --match title:Claude-4 Return
```


## PR Workflow

Each Claude does this when completing their phase:

```bash
# 1. Commit
git add .
git commit -m "feat([scope]): Phase X - [description]

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

# 2. Push
git push -u origin feature/[plan]-phaseX

# 3. Create PR
gh pr create --title "feat([scope]): Phase X - [description]" --body "## Summary
- [bullet points]

## Issues Closed
- Closes #XX

## Verification
- [x] npm run lint ✅
- [x] npm run typecheck ✅
- [x] npm run build ✅

🤖 Generated with Claude Code" --base [main_branch]
```


## Merge & Cleanup

CLAUDE 1 does this at the end:

```bash
cd [project_root]

# 1. Merge all PRs (in order!)
gh pr merge [PR-1] --merge
gh pr merge [PR-2] --merge
gh pr merge [PR-3] --merge

# 2. Pull changes
git pull origin [main_branch]

# 3. Cleanup worktrees
git worktree remove ../[project]-C2
git worktree remove ../[project]-C3
git worktree remove ../[project]-C4

# 4. Cleanup branches
git branch -d feature/[plan]-phase1
git branch -d feature/[plan]-phase2
git branch -d feature/[plan]-phase3

# 5. Final verification
npm run lint && npm run typecheck && npm run build
```


## Critical Rules

1. **NO FILE OVERLAP**: Each Claude works on DIFFERENT files
2. **ONE COMMIT PER PHASE**: Not per task
3. **GIT SAFETY**: Only one Claude commits at a time
4. **VERIFICATION BEFORE PR**: lint/typecheck/build must pass
5. **ORDERED MERGE**: PRs merged in order (phase1, phase2, phase3)


## Changelog

- **2.0.0** (2026-01-10): Extracted from strategic-planner.md for modularity
