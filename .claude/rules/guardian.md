<!-- v2.8.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

See CLAUDE.md Thor Gate section for commands and gates.

## Anti-Bypass

See CLAUDE.md Anti-Bypass + Mandatory Routing sections. Plan creation = `/planner` only (Plan 225). Task execution = task-executor only (Plan 182).

## Plan Closure = Merged (NON-NEGOTIABLE)

A plan is NOT done until ALL changes are merged to main AND documentation is current. `plan-db.sh complete` enforces: all wave PRs must be `MERGED` on GitHub (live check via `gh pr view`). Worktrees must be clean. No unmerged branches allowed at plan closure. All docs (CHANGELOG, README, TROUBLESHOOTING, ADRs) must be updated and version-aligned. Bypassing with `--force` requires explicit user approval.

## Git & PR

**NEVER create bare branches** — use `worktree-create.sh` or `wave-worktree.sh`. Hook `worktree-guard.sh` blocks `git branch`, `git checkout -b`, `git switch -c`. | Conventional commits | Lint+typecheck+test before commit | Build passes | ZERO debt (no TO-DO, FIX-ME, @ts-ignore) | **NEVER `git merge main` into wave branch** — use `git rebase origin/main` (see worktree-discipline.md)

## PR Post-Push Protocol (NON-NEGOTIABLE)

After every push on a PR, before merge:

1. **CI green**: Wait for full CI. Fix ALL failures in one commit (CI Batch Fix rule)
2. **Review comments**: `pr-threads.sh {pr} --no-cache` — check unresolved count
3. **Resolve all threads**: For each unresolved thread — analyze, fix code, commit, reply, resolve. Use `pr-comment-resolver` agent or manual fix. Zero unresolved threads required.
4. **Readiness check**: `pr-ops.sh ready {pr}` — must show 0 blockers
5. **Merge**: Only after steps 1-4 pass. `pr-ops.sh merge {pr}` enforces this automatically.

**Merging with unresolved PR comments = VIOLATION.** `wave-worktree.sh merge` blocks on unresolved threads.

## Execution Readiness Snapshot (NON-NEGOTIABLE)

Before execution or resume, run `execution-preflight.sh <worktree>`. Treat `dirty_worktree`, `gh_auth_not_ready`, `missing_troubleshooting`, and `missing_ci_knowledge` as blockers for auth/CI/deploy/PR work until resolved or explicitly acknowledged by the user.

**Git auth pre-check**: Before any `git push` or `gh` API call, verify the correct account is active. Multi-account setups auto-revert — always run the platform's account-switch command before push/PR operations.

If operational dashboards, caches, or metrics are older than the current work cycle, refresh them before using them for decisions. Stale observability treated as missing evidence.

## CI Batch Fix (NON-NEGOTIABLE)

Wait for FULL CI to complete before pushing fixes. Collect ALL failures. Fix ALL in one commit. Push once. Never fix-push-repeat per error. Max 3 rounds. **Pushing after fixing only 1 error while CI has more failures = REJECTED.**

## Zero Technical Debt (NON-NEGOTIABLE)

Resolve ALL issues, not just high-priority. Prioritize by severity but NEVER defer lower-priority items. Every CI error, lint warning, type error, test failure MUST be resolved. Accumulated debt = VIOLATION.

## Test Adapts to Code (NON-NEGOTIABLE)

When plan implementation changes break existing tests, **update tests to match new behavior**. NEVER revert working implementation to make old tests pass. Tests verify correctness of the NEW code, not preserve the OLD behavior. Reverting implementation to green-light stale tests = VIOLATION.

## Integration Completeness (NON-NEGOTIABLE)

New code MUST be wired into at least one consumer. New components MUST have a render site. Changed interfaces MUST have ALL consumers updated. Orphan code (created but never imported) = REJECTION. See `.claude/rules/testing-standards.md` for mock boundaries and fail-loud patterns.

**Wiring Coverage Gate**: When a shared helper/utility is created for N target files (specified in task description or inferable from context), verify it's imported and called in ALL N files, not a subset. Partial wiring = REJECTION.

**Thor MUST verify**: `grep -rn "import.*helper_name" target_dir/ | wc -l` matches expected count. If task says "add to 6 routers" and grep shows 3, REJECT.

_Why: Plan 100027 — `invalidate_admin_write_cache` helper created for 6 admin routers, but only wired into 3. Tests expected all 6 → 5 failures._

## Versioning Discipline (NON-NEGOTIABLE)

Every repo MUST have a versioning system. Every push to main MUST increment the version.

| Commit type                                            | Increment | Example         |
| ------------------------------------------------------ | --------- | --------------- |
| `fix:`, `chore:`, `docs:`, `test:`                     | **patch** | v1.2.3 → v1.2.4 |
| `feat:`                                                | **minor** | v1.2.3 → v1.3.0 |
| Breaking change (`BREAKING CHANGE:` or `!` after type) | **major** | v1.2.3 → v2.0.0 |

**Requirements**:

1. CHANGELOG.md MUST exist with `## [vX.Y.Z] - DD Mon YYYY` entries
2. Git tag `vX.Y.Z` MUST match latest CHANGELOG entry
3. Push without version increment = VIOLATION
4. **New repo onboarding**: if no CHANGELOG.md or no tags exist, create them before first plan

**Enforcement**: Agent MUST update CHANGELOG.md + create git tag on every commit to main. `version-check.sh` validates alignment.

## New Repo / Repo Audit Checklist

When onboarding a new repo or auditing existing ones, verify:

1. **Branch protection**: `branch-protect.sh check owner/repo [branch]` — must show PROTECTED
2. **If not protected**: `branch-protect.sh apply owner/repo [branch]` (requires GitHub Pro for private repos)
3. **Required settings**: `required_conversation_resolution: true` + `enforce_admins: true`
4. **Versioning**: CHANGELOG.md exists, git tags exist, latest tag matches CHANGELOG. If missing, create before first plan.
5. **Troubleshooting**: `TROUBLESHOOTING.md` exists in root. If missing, create before first plan.

Without branch protection, GitHub Web UI allows merging with unresolved review comments.

## Documentation Closure Gate — Thor 9b (NON-NEGOTIABLE)

At plan closure, Thor gate 9b verifies ALL documentation is current:

| Check              | Verify                                                      | REJECT if                   |
| ------------------ | ----------------------------------------------------------- | --------------------------- |
| TROUBLESHOOTING.md | `test -f TROUBLESHOOTING.md`                                | Missing from repo root      |
| Per-wave ADRs      | `ls docs/adr/*wave-summary*` or decision ADRs for each wave | Any wave without ADR        |
| CHANGELOG.md       | Latest entry matches current version                        | Stale or missing entry      |
| README.md          | Updated if public API/features changed                      | Outdated sections           |
| Version bump       | Git tag + CHANGELOG version incremented after plan          | Same version as before plan |

**Version alignment**: Every plan MUST increment the version. All docs must reflect the new version. `version-check.sh` validates.

## Anti-Cheating (NON-NEGOTIABLE)

Agents CHEAT when they: mark done without running tests | claim "tests pass" without showing output | say "out of scope" to skip hard work | defer issues to "next wave/PR/task" | suppress warnings instead of fixing them | mark blocked prematurely to avoid effort | leave `pass` or `...` stubs claiming "done" | write tests that assert nothing meaningful | disable lint rules instead of fixing violations | claim "pre-existing issue" to avoid fixing touched files.

**ALL of these = REJECTION by Thor + escalation to user.** Thor MUST run the actual commands and inspect output — NEVER trust executor claims.

**Touched file ownership**: If an executor modifies ANY line in a file, they own ALL issues in that file. "I only changed line 5" does not excuse the TO-DO on line 20. Fix it or don't touch the file.

## Assessment Coverage Gate (NON-NEGOTIABLE)

When a plan is based on a diagnostic report, security assessment, or audit document:

1. **Extract ALL findings**: Every finding (F-xx, B.x, C.x, etc.) MUST be listed explicitly
2. **Map every finding to a task**: Each finding → at least one plan task, OR explicit exclusion with user approval via AskUserQuestion
3. **Coverage matrix**: Planner MUST produce a `| Finding | Task | Status |` table visible to user BEFORE approval
4. **Silent exclusion = VIOLATION**: Skipping ANY finding without user acknowledgment = REJECTED. "Out of scope" or "deferred" without explicit approval = REJECTED
5. **Severity ordering**: Critical/High findings MUST be in early waves. Never defer Critical findings to "later"

_Why: Plan 18.5.0 silently skipped F-01 (Critical), F-02, F-03, F-04 (all High) from the assessment. Nobody noticed until production broke._

## Schema Migration Gate (NON-NEGOTIABLE)

When a task creates or modifies a database model/schema (any language, any ORM):

| ORM/Framework | Model change requires |
|---|---|
| SQLAlchemy (Alembic) | New file in `alembic/versions/` |
| Django | `python manage.py makemigrations` output committed |
| Prisma | `prisma migrate dev` output committed |
| TypeORM | New migration file in `migrations/` |
| Sequelize | New migration file |
| Raw SQL | Migration script in `migrations/` or equivalent |

**Thor MUST verify**: `new/modified model file` → `corresponding migration file in same PR`. Missing migration = REJECTION.

**Verify command** (generic): search for new model classes/tables in diff, then verify migration exists:
- Python/Alembic: `git diff --name-only | grep models/ && git diff --name-only | grep alembic/versions/`
- If model changed but no migration → REJECT

_Why: PR #235 added `PatToken` model without Alembic migration. Table never created in production. All users lost data access._

## Post-Deploy Smoke Test (NON-NEGOTIABLE)

Plans touching authentication, authorization, data access, or storage MUST include a smoke test task in the final wave:

1. **What to test**: Login → navigate → verify data is non-empty → verify correct user context
2. **How**: API call to a data endpoint that requires auth + scope. Assert `response.status == 200` AND `len(data) > 0`
3. **When**: After deploy to staging (CI) or as final Thor gate

**Empty data on authenticated endpoint = FAIL.** The smoke test must distinguish "no data because empty DB" from "no data because auth/token/scope is broken".

_Why: v19.1.0 deployed with broken PAT storage. All dashboards showed zero. No smoke test caught it._

## Post-Plan Learning Loop — Thor 10 (NON-NEGOTIABLE)

After every plan closure (PR merged, deploy verified), before marking the plan complete:

**Step 1: Analyze** — Review the execution for recurring patterns:

| Question | Look for |
|---|---|
| What broke that shouldn't have? | Test failures from our changes, not pre-existing |
| What was manually fixed that a rule could prevent? | Wiring gaps, missing params, import mismatches |
| What did hooks/CI catch that agents missed? | Formatting, lint, observability, workflow proof |
| What took multiple attempts? | Merge conflicts, signature mismatches, false CI signals |

**Step 2: Propose** — For each finding, propose a CONCRETE fix:

| Fix type | Where | Example |
|---|---|---|
| New rule/gate | `rules/*.md` or `guardian.md` | "Signature Change Impact" gate |
| KB entry | `plan-db.sh kb-write learning ...` | Reusable pattern for future plans |
| Script/hook fix | `.claude/scripts/` | ci-watch.sh false positive bug |
| Planner constraint | Task spec template | "Include caller update count" |

**Step 3: Apply** — Two-level update, commit separately from plan code:

| Level | Target | Content | Examples |
|---|---|---|---|
| Generic | `.claude/rules/*.md` | Universal rules (any repo/platform/language) | Signature impact gate, wiring coverage gate |
| Project-specific | Repo `CLAUDE.md`, `AGENTS.md` | Codebase conventions, gotchas, patterns | DI param pattern, test infra quirks |

**Step 4: Verify** — Confirm the new rule would have caught the original issue:
- Re-read the rule and mentally replay the failure scenario
- If the rule is too vague to be actionable, sharpen it

**Constraints**:
- `.claude/` rules MUST be generic (any repo, any platform, any language)
- Project-specific learnings go in repo `CLAUDE.md` "Project Learnings" section, `AGENTS.md`, or `MEMORY.md`
- Max 3 new generic rules per plan (merge with existing when possible)
- Every new rule MUST include a `_Why: Plan NNN — description_` annotation

## Verify Path Glob Rule (NON-NEGOTIABLE)

Task `verify` commands for NEW files MUST use glob patterns, not exact paths. Executors may place files in different but valid directories.

| WRONG | RIGHT |
|---|---|
| `test -f components/layout/FeedbackButton.tsx` | `find . -name 'FeedbackButton.tsx' -path '*/components/*'` |
| `test -f docs/adr/ADR-073-announcements-model-api.md` | `ls docs/adr/ADR-073*` |

**Planner MUST**: Use `find -name` or `ls glob*` in verify arrays for files that don't exist yet. Exact paths only for files that already exist in the repo.

_Why: Plan 100028 — T4-01 verify expected `components/layout/FeedbackButton.tsx` but executor created `components/feedback/FeedbackButton.tsx`. Thor rejected valid work due to path mismatch. Same issue hit TF-doc with ADR filename._

## PR Body Compliance (NON-NEGOTIABLE)

When CI includes a PR body/workflow compliance check, TF-pr tasks MUST update the PR body to include all required fields BEFORE pushing. Common requirements: Plan ID reference, checklist items (planner, executor, thor, workflow-proof), summary section.

**Executor MUST**: Read the CI compliance script to understand required PR body format, then `gh api --method PATCH` the PR body accordingly. Pushing code without valid PR body = CI failure on every push.

_Why: Plan 100028 — PR #256 failed CI 3 times because PR body was missing `check_agent_workflow_compliance.py` required checklist. Each failure cost a full CI cycle (~10 min)._

## Migration Quality Gate

Backend migrations (Python→Rust, framework changes, API rewrites) MUST follow `rules/migration-checklist.md`. Thor rejects migration PRs without E2E Playwright audit and endpoint response verification.

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done | Orphan code (created but never wired)
