# ADR 0001: Digest Scripts for Token Optimization

**Status**: Accepted
**Date**: 31 January 2026
**Decision**: Replace all verbose CLI output with digest scripts that return compact JSON.

## Context

Claude Code's token cost is dominated by two factors:

1. **Context re-send**: Every Bash tool call re-sends the entire conversation as input tokens (~12K+ base).
2. **Raw output ingestion**: CLI tools (CI logs, PR comments, npm, build, tests) produce hundreds to thousands of lines of output, 90%+ of which is noise.

Analysis showed ~$4.50/plan cycle wasted on raw log processing. Key waste patterns:

- `gh run view --log-failed`: 10K+ lines dumped, only ~20 error lines relevant
- `gh pr view --comments`: Bot comments (Vercel, Dependabot, CodeQL) outnumber human comments 5:1
- `npm install`: Hundreds of lines for "added 1234 packages"
- `npm run build`: Next.js build output 100-300 lines, errors in 2-3 lines
- `git diff` on large branches: Thousands of lines when only file summary needed

## Decision

Create a family of **digest scripts** that:

1. Run commands server-side, capturing output to temp files (never echoed raw)
2. Parse output with grep/perl/jq to extract only actionable data
3. Return compact JSON (~100-200 tokens vs ~2000-10000 raw)
4. Cache results with configurable TTL to avoid repeated API calls
5. Are enforced via PreToolUse hook (exit 2 = blocked)

## Scripts

### External Services (in `~/.claude/scripts/`)

| Script              | Replaces                                               | Output                                          | Cache TTL |
| ------------------- | ------------------------------------------------------ | ----------------------------------------------- | --------- |
| `ci-digest.sh`      | `gh run view --log-failed`                             | Run status + deduplicated errors                | 60s       |
| `pr-digest.sh`      | `gh pr view --comments`, `gh api .../pulls/N/comments` | Human-only unresolved threads, review decisions | 30s       |
| `deploy-digest.sh`  | `vercel logs`, `vercel inspect`                        | Deployment status + errors only                 | 45s       |
| `service-digest.sh` | All three above                                        | Unified entry: `ci\|pr\|deploy\|all` (parallel) | per-sub   |

### Development Operations

| Script                | Replaces                                   | Output                                                             | Cache TTL |
| --------------------- | ------------------------------------------ | ------------------------------------------------------------------ | --------- |
| `npm-digest.sh`       | `npm install`, `npm ci`                    | packages added/removed, audit summary, peer warnings               | 120s      |
| `build-digest.sh`     | `npm run build`                            | Framework-detected (Next.js/Vite), errors, warnings, bundle size   | 30s       |
| `test-digest.sh`      | `npx vitest`, `npx jest`, `npx playwright` | Auto-detect framework, only failures as JSON                       | 15s       |
| `audit-digest.sh`     | `npm audit`                                | Only critical/high items, fixable count                            | 300s      |
| `diff-digest.sh`      | `git diff main...feature`                  | File list, insertions/deletions, type breakdown, top files         | 30s       |
| `merge-digest.sh`     | Manual Read of conflicted files            | Conflict blocks as JSON with ours/theirs content                   | none      |
| `error-digest.sh`     | Reading raw stack traces                   | Parse stdin: error type, message, file:line, strip node_modules    | none      |
| `migration-digest.sh` | `npx prisma migrate`, `npx drizzle-kit`    | Tables modified, destructive changes, pending migrations           | 60s       |
| `git-digest.sh`       | `git status`, `git log`, `git branch`      | Branch, clean/dirty, ahead/behind, staged/unstaged counts, commits | 5s        |

### Shared Infrastructure

| File                  | Purpose                                                                          |
| --------------------- | -------------------------------------------------------------------------------- |
| `lib/digest-cache.sh` | Shared cache layer: `digest_cache_get`, `digest_cache_set`, `digest_cache_flush` |
| Cache directory       | `/tmp/claude-digest-cache/`                                                      |

## Enforcement

### PreToolUse Hook (`prefer-ci-summary.sh`)

Blocks raw commands with `exit 2` and suggests the digest alternative:

- `gh run view --log*` → `service-digest.sh ci`
- `gh pr view --comments` → `service-digest.sh pr`
- `gh api .../pulls/N/comments` → `service-digest.sh pr N`
- `vercel logs` → `service-digest.sh deploy`
- `npm install` / `npm ci` → `npm-digest.sh`
- `npm run build` → `build-digest.sh`
- `npm audit` → `audit-digest.sh`
- `npx vitest/jest/playwright` → `test-digest.sh`
- `git diff` (without --stat) → `diff-digest.sh`
- `npx prisma/drizzle-kit migrate` → `migration-digest.sh`

### CLAUDE.md Rules

Section "Digest Scripts (NON-NEGOTIABLE)" with full mapping table. Read by every Claude session.

## Consequences

### Positive

- **~70-80% token reduction** on external service interactions
- **~50-60% reduction** on build/test/install operations
- **Cache prevents redundant API calls** across agents (Thor, executor, release manager)
- **Structured JSON** easier for Claude to parse than raw text
- **Server-side processing**: logs never enter tool output raw

### Negative

- 12 new scripts to maintain
- Cache staleness possible (mitigated by `--no-cache` flag and short TTLs)
- Hook may block legitimate use cases (mitigated by allow-list patterns)

### Neutral

- `vercel-helper.sh` remains for backward compatibility
- `ci-check.sh` removed (deprecated); replaced by `ci-digest.sh checks` subcommand
- Project-specific `ci-summary.sh` still preferred when available

## Amendments

| Version | Date        | Change                                                                                                            |
| ------- | ----------- | ----------------------------------------------------------------------------------------------------------------- |
| v9.16.0 | 27 Feb 2026 | All digest scripts now support `--compact` flag (YAML output); see ADR 0021 for JSON vs YAML serialization policy |
| v9.16.0 | 27 Feb 2026 | `ci-check.sh` removed; replaced by `ci-digest.sh checks` subcommand                                               |

## Usage Examples

```bash
# Single service check
service-digest.sh ci                  # CI status for current branch
service-digest.sh pr 42               # PR #42 review digest
service-digest.sh deploy              # Latest Vercel deployment

# All services at once (parallel)
service-digest.sh all

# Development operations
npm-digest.sh install                 # Install with compact output
build-digest.sh                       # Build with JSON summary
test-digest.sh --suite unit           # Only unit tests
audit-digest.sh                       # Security audit
diff-digest.sh main feature/auth      # Diff summary before merge
merge-digest.sh                       # Conflict blocks after merge

# Error parsing (pipe from any command)
npm test 2>&1 | error-digest.sh       # Parse test failures
error-digest.sh --run "npm run build" # Run and parse in one call

# Database migrations
migration-digest.sh status            # Pending migrations
migration-digest.sh push              # Push schema changes

# Cache management
service-digest.sh flush               # Clear all cached digests
build-digest.sh --no-cache            # Force fresh data
```
