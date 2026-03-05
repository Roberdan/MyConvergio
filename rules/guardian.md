<!-- v2.5.0 -->

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

A plan is NOT done until ALL changes are merged to main. `plan-db.sh complete` enforces: all wave PRs must be `MERGED` on GitHub (live check via `gh pr view`). Worktrees must be clean. No unmerged branches allowed at plan closure. Bypassing with `--force` requires explicit user approval.

## Git & PR

**NEVER create bare branches** — use `worktree-create.sh` or `wave-worktree.sh`. Hook `worktree-guard.sh` blocks `git branch`, `git checkout -b`, `git switch -c`. | Conventional commits | Lint+typecheck+test before commit | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore) | **NEVER `git merge main` into wave branch** — use `git rebase origin/main` (see worktree-discipline.md)

## PR Post-Push Protocol (NON-NEGOTIABLE)

After every push on a PR, before merge:

1. **CI green**: Wait for full CI. Fix ALL failures in one commit (CI Batch Fix rule)
2. **Review comments**: `pr-threads.sh {pr} --no-cache` — check unresolved count
3. **Resolve all threads**: For each unresolved thread — analyze, fix code, commit, reply, resolve. Use `pr-comment-resolver` agent or manual fix. Zero unresolved threads required.
4. **Readiness check**: `pr-ops.sh ready {pr}` — must show 0 blockers
5. **Merge**: Only after steps 1-4 pass. `pr-ops.sh merge {pr}` enforces this automatically.

**Merging with unresolved PR comments = VIOLATION.** `wave-worktree.sh merge` blocks on unresolved threads.

## CI Batch Fix (NON-NEGOTIABLE)

Wait for FULL CI to complete before pushing fixes. Collect ALL failures. Fix ALL in one commit. Push once. Never fix-push-repeat per error. Max 3 rounds. **Pushing after fixing only 1 error while CI has more failures = REJECTED.**

## Zero Technical Debt (NON-NEGOTIABLE)

Resolve ALL issues, not just high-priority. Prioritize by severity but NEVER defer lower-priority items. Every CI error, lint warning, type error, test failure MUST be resolved. Accumulated debt = VIOLATION.

## Test Adapts to Code (NON-NEGOTIABLE)

When plan implementation changes break existing tests, **update tests to match new behavior**. NEVER revert working implementation to make old tests pass. Tests verify correctness of the NEW code, not preserve the OLD behavior. Reverting implementation to green-light stale tests = VIOLATION.

## Integration Completeness (NON-NEGOTIABLE)

New code MUST be wired into at least one consumer. New components MUST have a render site. Changed interfaces MUST have ALL consumers updated. Orphan code (created but never imported) = REJECTION. See `~/.claude/rules/testing-standards.md` for mock boundaries and fail-loud patterns.

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

Without branch protection, GitHub Web UI allows merging with unresolved review comments.

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done | Orphan code (created but never wired)
