# Claude Global Config Audit Remediation Plan

**Source**: Consolidated Deep Audit Report 2026-02-27 (Opus 4.6 + Codex cross-validated)
**Score**: 87/100 — Exceptional with 3 critical issues

## P0 — IMMEDIATE

- F-01: Harden `settings.json` permission posture — `permissions.defaultMode = "bypassPermissions"` + `skipDangerousModePermissionPrompt = true`. Set `defaultMode` to `"ask"` or allowlist-first. Disable dangerous-mode skip
- F-02: Fix/remove missing hook script references — `settings.json` references scripts that don't exist: `~/.claude/scripts/env-vault-guard.sh` (MISSING), `~/.claude/scripts/model-registry-refresh.sh` (MISSING). Create scripts or remove hook entries
- F-03: Quarantine/rewrite `env-vault.sh` — uses full `.env` content with `gh secret set ... -b "$(cat "$env_file")"`, `log_metadata()` interpolates unescaped values into SQL, multiple `|| true` suppressions. Add SQL parameterization, strict error handling, explicit secret policy

## P1 — HIGH

- F-04: Fix MCP codegraph hardcoded path — `mcp.json` points to `/Users/roberdan/GitHub/MirrorBuddy`. Replace with dynamic workspace variable or per-project override
- F-05: Reduce disk bloat (3.8 GB) — `projects/`: 3.1 GB (5,695 files), `debug/`: 524 MB. Add periodic cleanup script with age-based reaper (>7 days for debug/, archive completed plans)
- F-06: Resolve shell policy contradictions — `CLAUDE.md` says "NEVER pipe to tail/head/grep/cat" but multiple skills/agents prescribe those pipelines (compliance-checker.agent.md, planner.agent.md, documentation/SKILL.md). Create single canonical policy + generated derivatives
- F-07: Fix stale/missing references — `agents/core_utility/CONSTITUTION.md` references non-existent `~/.claude/rules/execution.md` and `~/.claude/rules/file-size-limits.md`. Add reference integrity check, fix or remove dead links
- F-08: Deduplicate instruction sets — skills and copilot-agents overlap heavily (optimize-project SKILL.md ↔ optimize-project.agent.md). Thor/worktree/anti-bypass rules duplicated across CLAUDE.md, AGENTS.md, guardian.md. ~2K tokens saved per session. Single canonical source per domain
- F-09: Harden script robustness — of 153 scripts: 46 missing `set -euo pipefail`, 137 missing `trap` cleanup, 138 missing usage/help, 33 non-executable. Add script QA profile, enforce strict mode for entrypoints

## P2 — MEDIUM

- F-10: Delete anomalous `~/` directory in repo root
- F-11: Delete nested `~/.claude/.claude/` (3.3 MB stale ctags)
- F-12: Clean 104 empty session-env directories
- F-13: Prune 12+ empty plan directories
- F-14: Move generated research report artifacts out of `agents/` tree
- F-15: Set sensitive config files to 0600 (settings.json, mcp.json are world-readable)
- F-16: Archive disabled skills from active-looking locations
- F-17: Add `.DS_Store` to recursive `.gitignore`
- F-18: Move project-specific agents to namespaced opt-in paths
- F-19: Add token budget enforcement per instruction type

## P3 — BACKLOG

- F-20: Add `token-audit.sh` gate for config repo itself
- F-21: Replace `python3 -m json.tool` with `jq .` in `guard-settings.sh`
- F-22: Archive 356 completed plan files
- F-23: Add agent-schema.json validation for frontmatter/tool names
