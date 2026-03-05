<!-- ADR-0032 | 05 Mar 2026 -->

# ADR-0032: Workflow Hardening — Single Source of Truth

## Status: Accepted

## Context

Agents (Claude + Copilot) routinely forgot workflow steps: Thor validation skipped, planner bypassed, strategic-planner.md contradicted commands/planner.md, CodeGraph CLI hooks referenced non-existent binary, 5 Copilot CLI skills were missing.

Root causes: workflow instructions fragmented across 9+ locations with contradictions, no mechanical enforcement of Thor, duplicate agent files with divergent content.

## Decision

1. **SSOT**: `commands/planner.md` is the single source for planning workflow. `strategic-planner.md` becomes a lean pointer. CLAUDE.md holds the authoritative pipeline description; Anti-Bypass and Thor sections reference hooks, not repeat rules.
2. **Mechanical enforcement**: `enforce-thor-completion.sh` PreToolUse hook hard-blocks `plan-db.sh complete` if any task lacks `validated_at`. Policy alone was insufficient.
3. **Dedup agents**: Root-level duplicates deleted. Only `agents/core_utility/` copies kept.
4. **ADR-0017 compliance**: Removed CodeGraph CLI hooks from settings.json (no binary exists).
5. **Copilot CLI parity**: Created 5 missing `.github/skills/` entries.
6. **Script hardening**: Tilde expansion fix in plan-db-verify.sh, active-session safety in worktree-cleanup.sh.

## Consequences

- Thor bypass is mechanically impossible (hook denies completion without validation)
- No more contradictory instructions across duplicated files
- Copilot CLI has full skill parity with Claude Code
- Script bugs that caused false verify failures are fixed
