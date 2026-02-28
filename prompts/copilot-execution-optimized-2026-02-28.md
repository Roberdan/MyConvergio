# Copilot Optimized Execution — 28 Feb 2026

3 plans, 22 tasks total. All routed to `copilot-worker.sh` with per-task model selection.

## Setup

```bash
export PATH="$HOME/.claude/scripts:$PATH"
DB=~/.claude/data/dashboard.db
```

## Plan 278: MirrorBuddy (5 tasks, 2 waves)

**Project**: ~/GitHub/MirrorBuddy | **Theme**: cleanup

### Start

```bash
plan-db.sh start 278
```

### W1 — Cleanup & Knowledge (sync → PR)

```bash
wave-worktree.sh create 278 1161
WORKTREE=$(plan-db.sh get-wave-worktree 1161)
cd "$WORKTREE"
```

Execute sequentially (3 tasks):

```bash
copilot-worker.sh 5966 --model gpt-5.1-codex-mini --timeout 600
# T1-01: Fix aria-label hardcoded strings in 3 loading.tsx files
# For [locale] files: use getTranslations() from next-intl/server
# For admin/loading.tsx: use static English aria-label (no i18n provider)
# Add loading.ariaLabel, loading.chatAriaLabel to all 5 locale message files
# Verify: npx eslint src/app/*/loading.tsx src/app/*/*/loading.tsx --max-warnings 0

copilot-worker.sh 5967 --model gpt-5.3-codex --timeout 600
# T1-02: Run full test suite, fix any broken tests
# Verify: npm run test:unit -- --reporter=dot

copilot-worker.sh 5968 --model gpt-5.1-codex-mini --timeout 600
# T1-03: Create ~/.claude/data/ci-knowledge/mirrorbuddy.md from src/.claude/ci-knowledge.md
```

Wave completion:

```bash
plan-db.sh validate-wave 1161
wave-worktree.sh merge 278 1161
```

### WF — Closure (sync → PR)

```bash
wave-worktree.sh create 278 1162
WORKTREE=$(plan-db.sh get-wave-worktree 1162)
cd "$WORKTREE"

copilot-worker.sh 5969 --model gpt-5.3-codex --timeout 600
# TF-tests: Verify all tests pass, no duplicates

copilot-worker.sh 5970 --model gpt-5.3-codex --timeout 600
# TF-pr: Create PR, ensure CI passes, merge

plan-db.sh validate-wave 1162
wave-worktree.sh merge 278 1162
plan-db.sh complete 278
```

---

## Plan 279: VirtualBPM (10 tasks, 4 waves, 2 PRs)

**Project**: ~/GitHub/VirtualBPM | **Theme**: security + quality
**Merge strategy**: W1 batch + W2 sync (1 PR), W3 batch + WF sync (1 PR)

### Start

```bash
plan-db.sh start 279
```

### W1 — Core Hardening (batch — no PR, commits only)

```bash
wave-worktree.sh create 279 1163
WORKTREE=$(plan-db.sh get-wave-worktree 1163)
cd "$WORKTREE"
```

Execute (3 tasks):

```bash
copilot-worker.sh 5971 --model gpt-5.3-codex --timeout 900
# T1-01: Migrate BaseHTTPMiddleware to pure ASGI in audit.py, telemetry.py, request_id.py
# Use ASGI protocol directly (scope, receive, send). Keep same functionality.
# Verify: grep -L 'BaseHTTPMiddleware' webapp/middleware/{audit,telemetry,request_id}.py | wc -l | grep 3

copilot-worker.sh 5972 --model gpt-5.3-codex --timeout 900
# T1-02: Create webapp/core/settings.py with Pydantic BaseSettings singleton
# Move all os.getenv/os.environ calls to Settings fields. Update consumers.
# Verify: python3 -c 'from webapp.core.settings import Settings; s = Settings(); print(s)'

copilot-worker.sh 5973 --model gpt-5.3-codex --timeout 600
# T1-03: Enforce secure=True on session cookies in production
# Add SameSite=Lax. Use Settings.ENVIRONMENT to toggle.
# Add Fernet encryption for token cache file.
```

Wave completion (batch — commit only, no PR):

```bash
plan-db.sh validate-wave 1163
wave-worktree.sh batch 279 1163
```

### W2 — Refactoring & CI (sync → PR covers W1+W2)

```bash
wave-worktree.sh create 279 1164
WORKTREE=$(plan-db.sh get-wave-worktree 1164)
cd "$WORKTREE"
```

Execute (3 tasks):

```bash
copilot-worker.sh 5974 --model gpt-5.3-codex --timeout 900
# T2-01: Split okr_service.py (879 LOC) into okr_crud.py, okr_scoring.py, okr_reporting.py
# Keep okr_service.py as facade re-exporting all public functions
# Verify: wc -l webapp/services/okr_service.py | awk '$1 < 100'

copilot-worker.sh 5975 --model gpt-5.1-codex-mini --timeout 600
# T2-02: Add uv pip cache to CI quality job
# Cache ~/.cache/uv between runs. Pin installer checksums.

copilot-worker.sh 5976 --model gpt-5.3-codex --timeout 600
# T2-03: Audit vendor JS bundle (524KB). Remove unused vendor libs.
# Tree-shake what remains. Lazy-load rarely-used admin routers.
# Verify: du -sk webapp/static/vendor/ | awk '$1 < 500'
```

Wave completion (sync — creates PR for W1+W2 combined):

```bash
plan-db.sh validate-wave 1164
wave-worktree.sh merge 279 1164
```

### W3 — Tests & Housekeeping (batch)

```bash
wave-worktree.sh create 279 1165
WORKTREE=$(plan-db.sh get-wave-worktree 1165)
cd "$WORKTREE"

copilot-worker.sh 5977 --model gpt-5.3-codex --timeout 600
# T3-01: Expand E2E smoke tests. Cover auth flow, chat, admin CRUD, OKR endpoints.

copilot-worker.sh 5978 --model gpt-5.1-codex-mini --timeout 600
# T3-02: Fix README version badge. Move loose markdown to docs/. Create docs/msrest-migration.md.

plan-db.sh validate-wave 1165
wave-worktree.sh batch 279 1165
```

### WF — Closure (sync → PR covers W3+WF)

```bash
wave-worktree.sh create 279 1166
WORKTREE=$(plan-db.sh get-wave-worktree 1166)
cd "$WORKTREE"

copilot-worker.sh 5979 --model gpt-5.3-codex --timeout 600
# TF-tests: Consolidate all test files. Run full suite. No duplicates.

copilot-worker.sh 5980 --model gpt-5.3-codex --timeout 600
# TF-pr: Create PR, CI green, merge

plan-db.sh validate-wave 1166
wave-worktree.sh merge 279 1166
plan-db.sh complete 279
```

---

## Plan 280: ClaudeConfig Hardening (7 tasks, 3 waves, 1 PR)

**Project**: ~/.claude | **Theme**: security
**Merge strategy**: W1 batch + W2 batch + WF sync (1 PR via commit to main)

### Start

```bash
plan-db.sh start 280
```

### W1 — Hook Parity & Agent Hardening (batch)

```bash
# No wave-worktree for ~/.claude (config repo, not standard git project)
cd ~/.claude

copilot-worker.sh 5981 --model gpt-5.3-codex --timeout 900
# T1-01: Copy+adapt 10 hooks to copilot-config/hooks/ for parity
# Hooks: session-file-lock, session-file-unlock, worktree-guard, enforce-plan-db-safe,
#         guard-plan-mode, enforce-plan-edit, warn-bash-antipatterns, prefer-ci-summary,
#         warn-infra-plan-drift, warn-context-window

copilot-worker.sh 5982 --model gpt-5.1-codex-mini --timeout 600
# T1-02: Copy hooks/lib/ to copilot-config/hooks/lib/

copilot-worker.sh 5983 --model gpt-5.3-codex --timeout 900
# T1-03: Add disallowedTools to 13 agents needing restrictions
# (research, po, taskmaster, diana, socrates, marcus, xavier, wanda,
#  plan-reviewer, plan-business-advisor, plan-post-mortem, adversarial-debugger, sentinel)

plan-db.sh validate-wave 1167
git add -A && git commit -m "feat: hook parity and agent hardening (W1)"
```

### W2 — Path Hardening & Cleanup (batch)

```bash
copilot-worker.sh 5984 --model gpt-5.1-codex-mini --timeout 600
# T2-01: Replace 11 hardcoded /Users/roberdan/ with $HOME or ~

copilot-worker.sh 5985 --model gpt-5.1-codex-mini --timeout 600
# T2-02: Remove build artifacts, fix paths in research reports

plan-db.sh validate-wave 1168
git add -A && git commit -m "fix: path hardening and artifact cleanup (W2)"
```

### WF — Validation & Commit (sync)

```bash
copilot-worker.sh 5986 --model gpt-5.3-codex --timeout 600
# TF-tests: Run project-audit, verify all constraints

copilot-worker.sh 5987 --model gpt-5.1-codex-mini --timeout 600
# TF-pr: Final commit, push to main

plan-db.sh validate-wave 1169
git add -A && git commit -m "chore: validation and final cleanup (WF)"
git push origin main
plan-db.sh complete 280
```

---

## Execution Order

1. **Plan 278** (MirrorBuddy) — 5 tasks, ~1h — smallest, quick win
2. **Plan 279** (VirtualBPM) — 10 tasks, ~3h — largest effort
3. **Plan 280** (ClaudeConfig) — 7 tasks, ~2h — infra/config

## Rules

1. **copilot-worker.sh handles everything**: TDD, Thor per-task, status updates
2. **Thor per-wave**: `plan-db.sh validate-wave` after all tasks in wave
3. **Batch merge**: `wave-worktree.sh batch` — commit only, no PR
4. **Sync merge**: `wave-worktree.sh merge` — PR + CI + squash merge
5. **CI batch fix**: Wait for FULL CI, fix ALL failures in ONE commit, max 3 rounds
6. **If task fails 2x**: `plan-db.sh log-failure {plan_id} {task_id} "approach" "reason"`, try different approach
7. **Never git merge main**: Use `git rebase origin/main`
8. **Plan complete**: `plan-db.sh complete {plan_id}` only after ALL waves done + merged
