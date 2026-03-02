<!-- v2.4.0 -->

# Process Guardian

## Triggers

Plan proposed | Work claimed complete | PR suggested | Scope changed

## Done Criteria

"works" = tested, no errors, output shown | "done" = written, tests pass, committed | "fixed" = reproduced, fixed, test proves it | List ALL items with [x]/[ ] + verification method. Each F-xx: [x] with evidence | Disclose anything added beyond request. User approves closure.

## Thor

See CLAUDE.md Thor Gate section for commands and gates.

## Anti-Bypass

See CLAUDE.md Anti-Bypass + Mandatory Routing sections. Plan creation = `/planner` only (Plan 225). Task execution = task-executor only (Plan 182).

## Git & PR

Branch: feature/, fix/, chore/ | Conventional commits | Lint+typecheck+test before commit | Build passes | ZERO debt (no TODO, FIXME, @ts-ignore) | **NEVER `git merge main` into wave branch** — use `git rebase origin/main` (see worktree-discipline.md § Git Graph Hygiene)

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

## New Repo / Repo Audit Checklist

When onboarding a new repo or auditing existing ones, verify:

1. **Branch protection**: `branch-protect.sh check owner/repo [branch]` — must show PROTECTED
2. **If not protected**: `branch-protect.sh apply owner/repo [branch]` (requires GitHub Pro for private repos)
3. **Required settings**: `required_conversation_resolution: true` + `enforce_admins: true`

Without branch protection, GitHub Web UI allows merging with unresolved review comments.

## Guardrails

Avatar WebP | EventSource .close() | Lazy-load heavy deps | No N+1 without $transaction | Same approach fails twice → different strategy | Stuck → ask user | Reject if: Errors suppressed | Steps skipped | Verification promised but not done | Orphan code (created but never wired)
