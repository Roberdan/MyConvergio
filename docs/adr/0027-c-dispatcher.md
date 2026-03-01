# ADR-0027: c Dispatcher Architecture

**Status**: Accepted
**Date**: 01 Mar 2026
**Plan**: 290 (c-Dispatcher-TokenOptimization)

## Context

121 scripts in `~/.claude/scripts/` with verbose names + path prefix consumed ~200K tokens/month in script invocations. JSON output with null/0/false fields added ~650K tokens/month in wasted context. Combined: ~850K tokens/month waste.

Previous state: agents wrote `service-digest.sh ci`, `plan-db.sh get-context 290`, `db-digest.sh token-stats` — each name/path consumes 3-8 tokens before any logic runs. At 100+ daily invocations, this compounds.

## Decision

Single dispatcher `c` wrapping all 121 scripts via short subcommand groups:

| Group    | Maps to                               | Subcommands                                         |
| -------- | ------------------------------------- | --------------------------------------------------- |
| `c d`    | service/git/diff/build/test digests   | ci, pr, deploy, git, build, test, diff              |
| `c p`    | plan-db.sh + plan-db-safe.sh          | ctx, start, done, val, wave, import, complete, tree |
| `c db`   | db-digest.sh                          | stats, token-stats, monthly, tasks, waves           |
| `c w`    | wave-worktree.sh                      | create, merge, status, cleanup, batch               |
| `c lock` | file-lock.sh                          | acq, rel, list                                      |
| `c reap` | session-reaper.sh                     | pre, post, all                                      |
| `c ci`   | ci-watch.sh + ci-digest.sh            | watch, checks                                       |
| `c git`  | worktree-check.sh + worktree-guard.sh | check, guard                                        |

Compact output engine (`lib/c-compact.sh`): `c_strip_defaults` removes null/0/false/[] from JSON output via inline python3. Applied automatically via `c_out` pipe on all digest commands.

**Key design decisions**:

- NO key abbreviation (status→s rejected: breaks hook/Thor/coordinator downstream consumers)
- `c git check` has NO `c_out` pipe (worktree-check.sh emits ANSI text, not JSON)
- `c p done` only (removed redundant `c p safe` alias)
- python3 guard in c-compact.sh: passthrough if python3 unavailable

## Backward Compatibility

C-01: All original scripts remain unchanged and callable directly. `c` is additive.

## Consequences

- ~200K tokens/month saved from shorter invocation names
- ~650K tokens/month saved from null/0/false stripping on digest output
- `c db token-stats` / `c db monthly` eliminate need for raw SQL on dashboard.db
- `c [group] --help` shows original script equivalent for debugging
- New scripts must be manually added to `c` routing table (no auto-discovery)
