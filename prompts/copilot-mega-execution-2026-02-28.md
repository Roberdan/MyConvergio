# MEGA EXECUTION PROMPT — 28 Feb 2026

Execute 3 plans + audit old plans. Linux machine is offline and unreliable — ALL work must be done HERE.

## Setup

```bash
export PATH="$HOME/.claude/scripts:$PATH"
DB=~/.claude/data/dashboard.db
```

## Phase 0: Verify Enforcement (30 seconds)

```bash
bash ~/.claude/scripts/tests/test-thor-enforcement.sh
```

Expected: 53/53 PASS. If ANY fails: STOP.

## Phase 1: Audit Completed Plans (verify-only)

Plans 265 and 266 are CANCELLED (replaced by 269 and 270). But many older plans were completed with the old `plan-db-safe-auto` bypass (pre-Thor trigger). Verify the code exists.

### 1.1 Quick audit — check if PRs were merged

For each "done" plan, verify the work is in the repo's main branch:

```bash
# Plans to audit (all validated by old bypass):
# 228 (MirrorBuddy), 242 (VirtualBPM), 246 (VirtualBPM), 247 (VirtualBPM)
# 251 (VirtualBPM), 257 (VirtualBPM), 259 (VirtualBPM), 262 (VirtualBPM)
# 263 (MirrorBuddy), 264 (Claude Infra), 267 (MyConvergio)

# For each plan: check git log for related commits
for PLAN_ID in 228 242 246 247 251 257 259 262 263 264 267; do
  PLAN_NAME=$(sqlite3 "$DB" "SELECT name FROM plans WHERE id=$PLAN_ID;")
  PROJECT=$(sqlite3 "$DB" "SELECT pr.path FROM plans p JOIN projects pr ON p.project_id=pr.id WHERE p.id=$PLAN_ID;")
  TASK_COUNT=$(sqlite3 "$DB" "SELECT tasks_done FROM plans WHERE id=$PLAN_ID;")
  echo "Plan $PLAN_ID ($PLAN_NAME): $TASK_COUNT tasks in $PROJECT"

  # Check for plan branch or commits
  if [ -d "$PROJECT" ]; then
    cd "$PROJECT"
    COMMITS=$(git log --oneline --since="2026-02-25" --all | wc -l)
    echo "  Recent commits: $COMMITS"
    cd -
  else
    echo "  WARNING: Project path not found locally"
  fi
done
```

### 1.2 Retroactively validate confirmed plans

For plans where code EXISTS in main (verified above):

```bash
# For each confirmed plan, retroactively validate all tasks
for PLAN_ID in 228 263; do  # Add other confirmed plan IDs
  TASKS=$(sqlite3 -cmd ".timeout 5000" "$DB" \
    "SELECT id FROM tasks WHERE plan_id=$PLAN_ID AND status='done' AND (validated_by='plan-db-safe-auto' OR validated_at IS NULL);")
  for TASK_DB_ID in $TASKS; do
    plan-db.sh validate-task "$TASK_DB_ID" "$PLAN_ID" thor 2>/dev/null || true
  done
  echo "Plan $PLAN_ID: retroactively validated"
done
```

For plans where code DOES NOT EXIST: report as "needs re-execution" but do NOT re-execute (focus on plans 269/270/271).

## Phase 2: Execute Plan 270 — VirtualBPM (33 tasks)

**Project**: ~/GitHub/VirtualBPM
**Plan ID**: 270
**Priority**: Do this FIRST (VirtualBPM is a Python/FastAPI project, different from MirrorBuddy)

### Start plan

```bash
plan-db.sh start 270
```

### Execute each wave sequentially

For EACH wave (W0 through WF):

```bash
# Get wave info
sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT w.id, w.wave_id, w.name, w.tasks_total
  FROM waves w WHERE w.plan_id = 270
  ORDER BY w.wave_id;
"

# For each task in the wave:
NEXT=$(sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT id, task_id, title, description, test_criteria
  FROM tasks WHERE plan_id = 270 AND status = 'pending'
  ORDER BY wave_id_fk, task_id LIMIT 1;
")
echo "$NEXT"
```

### Per-task workflow (MANDATORY)

1. `plan-db.sh update-task {DB_ID} in_progress "Started"`
2. Read task description and test_criteria
3. Write failing test (TDD RED)
4. Implement (TDD GREEN)
5. Run project tests/lint to verify no regressions
6. `plan-db-safe.sh update-task {DB_ID} done "Summary of changes"`
   - This auto-sets status to `submitted` (NOT done)
   - Then auto-calls `validate-task` with thor validator
   - Task becomes `done` only after Thor validation
7. Verify: `sqlite3 -cmd ".timeout 5000" "$DB" "SELECT status, validated_by FROM tasks WHERE id={DB_ID};"`
   - Expected: `done|thor`
8. If Thor REJECTS: fix issues, re-submit (max 3 rounds)
9. Move to next task

### Per-wave completion (MANDATORY — after ALL tasks in wave are done)

```bash
# 1. Thor per-wave validation (all 9 gates)
WAVE_DB_ID=$(sqlite3 -cmd ".timeout 5000" "$DB" "SELECT id FROM waves WHERE plan_id=270 AND wave_id='{WAVE}';")
plan-db.sh validate-wave $WAVE_DB_ID

# 2. Create PR + merge via wave-worktree
wave-worktree.sh merge 270 $WAVE_DB_ID
# This auto: commits, rebases onto main, push (force-with-lease), creates PR, waits CI, squash merges

# 3. If PR has review comments: resolve ALL before merge
# pr-threads.sh {pr_number} --no-cache  → check unresolved count
# Fix code, commit, reply, resolve. Zero unresolved threads required.

# 4. If CI fails: fix ALL failures in ONE commit, push, wait CI again (max 3 rounds)

# 5. Verify wave status after merge
sqlite3 -cmd ".timeout 5000" "$DB" "SELECT status FROM waves WHERE id=$WAVE_DB_ID;"
# Expected: done

# 6. Cleanup: verify no stale worktrees or branches
git worktree list  # Should only show main + active wave worktrees
git branch | grep "plan/270" || echo "Clean"

# 7. Proceed to next wave (creates fresh worktree from updated main)
```

### Plan completion (MANDATORY — after ALL waves done)

```bash
# 1. Verify all tasks done
sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT COUNT(*) FROM tasks WHERE plan_id=270 AND status NOT IN ('done','skipped','cancelled');
"
# Expected: 0

# 2. Complete the plan
plan-db.sh complete 270

# 3. Final cleanup checklist
git worktree list              # Only main worktree
git branch | grep "plan/270"   # No stale branches (should be empty)

# 4. Verify PR was merged
gh pr list --state merged --search "plan/270" --json number,title
```

## Phase 3: Execute Plan 269 — MirrorBuddy (35 tasks)

**Project**: ~/GitHub/MirrorBuddy
**Plan ID**: 269
**Priority**: Second (largest plan)

Same workflow as Phase 2. Key differences:

- Next.js/TypeScript project (not Python)
- Quality gates: `npm run ci:summary` after each wave
- i18n: `npx tsx scripts/i18n-sync-namespaces.ts --add-missing` after any UI text changes
- PostgreSQL must be running: `pg_isready || brew services start postgresql@17`

### Start plan

```bash
plan-db.sh start 269
```

### Execute each wave

Same per-task + per-wave workflow as Phase 2 (including PR creation, CI check, merge, cleanup).

Additional MirrorBuddy quality gates per wave:

- `npm run ci:summary` (lint + typecheck + build)
- `npm run test:unit -- --reporter=dot` (unit tests)
- After UI text changes: `npx tsx scripts/i18n-sync-namespaces.ts --add-missing`
- After schema changes: `npx prisma generate`
- `npm run i18n:check` (verify all 5 locales synced)

### Key task guidance

- **T0-01** (global-error.tsx): Remove useTranslations, use inline strings with locale detection from URL
- **T0-04** (chat/route.ts): Use AIProviderRouter.chatWithFailover(), see ADR 0130
- **T1-01** (Zod schemas): Create src/lib/validation/schemas/ directory
- **T2-03** (i18n): Run sync FIRST, then replace [TRANSLATE] markers
- **T4-02** (proxy.ts split): Keep default export in src/proxy.ts for Next.js (CRITICAL: only ONE proxy.ts in src/)
- **T5-02** (large files): tier-service.ts 713 LOC, user-trash-service.ts 700 LOC

### Plan completion

Same as Phase 2: verify all tasks done, `plan-db.sh complete 269`, cleanup worktrees/branches, verify PR merged.

## Phase 4: Execute Plan 271 — .claude Hardening + MyConvergio v10 (20 tasks)

**Project**: ~/.claude (global config)
**Plan ID**: 271
**Priority**: Third

### Start plan

```bash
plan-db.sh start 271
```

### Execute each wave

Same per-task + per-wave workflow as Phase 2.

Note: Plan 271 modifies ~/.claude/ (global config, NOT a git repo with PRs). Wave completion for this plan:

- Waves W0-W2: Commit changes in ~/.claude/ repo (`cd ~/.claude && git add -A && git commit`)
- Wave W3 (MyConvergio): Work in ~/GitHub/MyConvergio — this one gets a PR
- Wave WF: Create MyConvergio PR, verify CI, merge, tag v10.0.0

### Key task guidance

- **T0-01** (hooks.json): Change ALL `~/.copilot/hooks/` to `~/.claude/copilot-config/hooks/`
- **T0-02** (port hooks): Copy from ~/.claude/hooks/ and adapt for Copilot format
- **T1-01** (disallowedTools): Add YAML frontmatter field to agent .md files
- **T1-02** (split files): task-executor.md -> extract TDD workflow to separate file
- **T1-03** (research logs): Delete or redact /Users/roberdan/ paths
- **T3-01** (ecosystem-sync): Run dry-run FIRST, check output for secrets/private paths
- **T3-04** (CHANGELOG): Document ALL changes from W0-W3 in MyConvergio CHANGELOG
- **TF-pr** (MyConvergio release): Create PR, CI green, merge, `git tag v10.0.0`, push tag

### Plan completion

```bash
# 1. Verify all tasks done
sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT COUNT(*) FROM tasks WHERE plan_id=271 AND status NOT IN ('done','skipped','cancelled');
"
# Expected: 0

# 2. Complete the plan
plan-db.sh complete 271

# 3. Verify MyConvergio release
cd ~/GitHub/MyConvergio
git tag --list 'v10*'  # Should show v10.0.0
gh pr list --state merged --search "v10" --json number,title

# 4. Verify .claude config committed
cd ~/.claude && git status  # Should be clean

# 5. Run enforcement tests one final time
bash ~/.claude/scripts/tests/test-thor-enforcement.sh
# Expected: 53/53 PASS
```

## Phase 5: Final Verification

```bash
# 1. All 3 plans should be done
sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT id, name, status, tasks_total, tasks_done
  FROM plans WHERE id IN (269, 270, 271);
"
# Expected: all status='done', tasks_total = tasks_done

# 2. Thor enforcement still works
bash ~/.claude/scripts/tests/test-thor-enforcement.sh
# Expected: 53/53 PASS

# 3. No plans left in 'doing' state
sqlite3 -cmd ".timeout 5000" "$DB" "
  SELECT COUNT(*) FROM plans WHERE status = 'doing';
"
# Expected: 0

# 4. No orphan worktrees
git worktree list  # Should show ONLY main worktree for each repo

# 5. No stale plan branches
cd ~/GitHub/MirrorBuddy && git branch | grep "plan/" || echo "Clean"
cd ~/GitHub/VirtualBPM && git branch | grep "plan/" || echo "Clean"
cd ~/GitHub/MyConvergio && git branch | grep "plan/" || echo "Clean"

# 6. All PRs merged or closed
cd ~/GitHub/MirrorBuddy && gh pr list --state open --json number,title
cd ~/GitHub/VirtualBPM && gh pr list --state open --json number,title
cd ~/GitHub/MyConvergio && gh pr list --state open --json number,title
# Expected: no open PRs related to plans 269/270/271

# 7. No orphan file locks
file-lock.sh list  # Should be empty or only current session

# 8. MyConvergio v10 tag exists
cd ~/GitHub/MyConvergio && git tag --list 'v10*'
# Expected: v10.0.0

# 9. .claude config committed
cd ~/.claude && git status
# Expected: clean (nothing to commit)
```

## Rules (NON-NEGOTIABLE)

### Task Execution

1. **NEVER skip Thor validation.** Every task: `plan-db-safe.sh update-task` (auto-validates).
2. **TDD mandatory**: Write failing test FIRST, then implement.
3. **Max 250 lines per file.** Check `wc -l` before committing.
4. **Conventional commits.** English code, Italian conversation.
5. **If task fails 2x**: Log failure `plan-db.sh log-failure {plan_id} {task_id} "approach" "reason"`. Try different approach.
6. **SQLite concurrency**: Always use `-cmd ".timeout 5000"` with sqlite3 commands.

### Wave Completion

7. **Worktree per wave**: `wave-worktree.sh create {plan_id} {wave_db_id}` before first task.
8. **Thor per-wave**: `plan-db.sh validate-wave {wave_db_id}` after all tasks done.
9. **PR per wave**: `wave-worktree.sh merge {plan_id} {wave_db_id}` — creates PR, CI, merge.
10. **Resolve ALL PR comments** before merge. Zero unresolved threads.
11. **CI batch fix**: Wait for FULL CI. Fix ALL failures in ONE commit. Max 3 rounds.
12. **Cleanup after merge**: Verify worktree removed, branch deleted, wave status = done.

### Plan Completion

13. **TF-tests task**: Consolidate/deduplicate all tests before TF-pr.
14. **TF-doc task**: Update CHANGELOG + create ADRs for significant decisions.
15. **TF-pr task**: Create final PR, CI green, merge. Plan NOT done until TF-pr merged.
16. **Final cleanup**: No orphan worktrees, branches, processes, file locks, or open PRs.
17. **After ALL tasks done**: `plan-db.sh complete {plan_id}`

### Git Hygiene

18. **NEVER `git merge main`** into a wave branch. Use `git rebase origin/main`.
19. **NEVER work on main** directly. Always use worktree.
20. **NEVER force-push to main**. Only `--force-with-lease` on wave branches.

## Priority Order

1. **Plan 270** (VirtualBPM) — 33 tasks, different codebase, no conflicts
2. **Plan 269** (MirrorBuddy) — 35 tasks, largest effort
3. **Plan 271** (.claude + MyConvergio) — 20 tasks, infra/config
4. **Audit old plans** — retroactive validation only, no re-execution
