#!/usr/bin/env bash
# prefer-ci-summary.sh - PreToolUse hook on Bash
# Intercepts verbose commands and suggests token-efficient alternatives.
# Block = exit 2. Hint = exit 0. Allow = exit 0.
# Version: 1.2.0
#
# IMPORTANT: Block rules check BASE_CMD (before pipe), so
# "gh run view --log-failed | tail -200" is STILL blocked.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Extract the LAST command in a chain (after && or ;), before any pipe
# This ensures "cd /path && npm run build | tail" → "npm run build"
BASE_CMD=$(echo "$COMMAND" | sed 's/|.*//' | sed 's/.*&&//' | sed 's/.*;//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# === ALWAYS ALLOW: our optimized scripts ===
echo "$COMMAND" | grep -qE "digest\.sh|service-digest|pr-ops\.sh|code-pattern-check\.sh" && exit 0
# ci-summary WITH explicit flag → allow immediately
echo "$COMMAND" | grep -qE "ci-summary\.sh --(quick|full|all|lint|types|build|unit|i18n|e2e|a11y)" && exit 0
# Release/deploy scripts (no ^ anchor: may be after cd &&)
echo "$COMMAND" | grep -qE "(\./scripts/|npm run )(release|pre-push|pre-release)" && exit 0

# === HINT: wc -l (prefer grep -c for agents, but don't block) ===
# wc -l works fine on macOS; was incorrectly blocked before.
if echo "$COMMAND" | grep -qE "wc -l" && ! echo "$BASE_CMD" | grep -qE "^git (commit|tag)"; then
	echo "HINT: Prefer 'grep -c . <file>' over 'wc -l' for consistency." >&2
	exit 0
fi

# === BLOCK: CI LOGS (even with pipe) ===
if echo "$BASE_CMD" | grep -qE "gh run view.*--log"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh ci <run-id>' instead." >&2
	echo "ci-digest.sh processes logs server-side, returns ~200 tokens JSON." >&2
	exit 2
fi

# === BLOCK: PR COMMENTS (read only, allow writes with -f/-F/-X POST) ===
if echo "$BASE_CMD" | grep -qE "gh pr view.*--comments"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh pr <pr-number>' instead." >&2
	exit 2
fi
if echo "$BASE_CMD" | grep -qE "gh api.*pulls/[0-9]+/(comments|reviews)"; then
	# Allow write operations (replies, posting comments)
	if ! echo "$COMMAND" | grep -qE " -[fF] | --method | -X "; then
		echo "TOKEN-WASTE: Use 'service-digest.sh pr <pr-number>' instead." >&2
		exit 2
	fi
	# Hint for write operations: suggest pr-ops.sh
	if echo "$COMMAND" | grep -qE " -[fF] | -X "; then
		echo "HINT: Consider 'pr-ops.sh reply <pr> <comment_id> \"msg\"' instead." >&2
		exit 0
	fi
fi

# === BLOCK: PR MERGE (without readiness check) ===
if echo "$BASE_CMD" | grep -qE "^gh pr merge"; then
	echo "BLOCKED: Use 'pr-ops.sh merge <pr>' instead (runs readiness check first)." >&2
	exit 2
fi

# === BLOCK: PR VIEW (verbose, without --json) ===
if echo "$BASE_CMD" | grep -qE "^gh pr view" && ! echo "$COMMAND" | grep -qE "\-\-json"; then
	echo "TOKEN-WASTE: Use 'pr-ops.sh status <pr>' or 'pr-ops.sh ready <pr>' instead." >&2
	exit 2
fi

# Allow other gh commands (gh pr create, gh pr list, gh run list, etc.)
echo "$BASE_CMD" | grep -qE "^gh " && exit 0

# === BLOCK: VERCEL LOGS ===
if echo "$BASE_CMD" | grep -qE "(^vercel logs|vercel-helper\.sh logs)"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh deploy' instead." >&2
	exit 2
fi

# === BLOCK: NPM INSTALL ===
if echo "$BASE_CMD" | grep -qE "^npm (install|ci)( |$)"; then
	echo "TOKEN-WASTE: Use 'npm-digest.sh install' instead." >&2
	exit 2
fi

# === BLOCK: NPM AUDIT ===
if echo "$BASE_CMD" | grep -qE "^npm audit( |$)" && ! echo "$COMMAND" | grep -q "\-\-json"; then
	echo "TOKEN-WASTE: Use 'audit-digest.sh' instead." >&2
	exit 2
fi

# === BLOCK: BUILD ===
if echo "$BASE_CMD" | grep -qE "^npm run build( |$)"; then
	echo "TOKEN-WASTE: Use 'build-digest.sh' instead." >&2
	exit 2
fi

# === BLOCK: TESTS ===
if echo "$BASE_CMD" | grep -qE "^(npx (vitest|jest|playwright)|npm run test|npm test)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "TOKEN-WASTE: Use './scripts/ci-summary.sh --unit|--e2e' instead." >&2
	else
		echo "TOKEN-WASTE: Use 'test-digest.sh' instead." >&2
	fi
	exit 2
fi

# === BLOCK: VERBOSE NPM (lint/typecheck) ===
if echo "$BASE_CMD" | grep -qE "^npm run (lint|typecheck|test:unit)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "TOKEN-WASTE: Use './scripts/ci-summary.sh --quick' (lint+types) or '--full' (all)." >&2
	else
		echo "TOKEN-WASTE: Use '$HOME/.claude/scripts/test-digest.sh' instead." >&2
	fi
	exit 2
fi

# === HINT: ci:summary default → suggest --quick ===
if echo "$BASE_CMD" | grep -qE "^(npm run ci:summary|\\./scripts/ci-summary\\.sh)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "HINT: Consider './scripts/ci-summary.sh --quick' for faster feedback (skips build)." >&2
		exit 0
	fi
fi

# === BLOCK: GIT DIFF (all forms except --stat-only) ===
# Allow: git diff --stat (compact, used in commit verify)
# Block: bare git diff, git diff --cached, git diff --name-only, git diff branch
if echo "$BASE_CMD" | grep -qE "^git diff"; then
	if echo "$BASE_CMD" | grep -qE "^git diff --stat( |$)"; then
		exit 0
	fi
	echo "TOKEN-WASTE: Use 'git-digest.sh --full' for file lists, 'diff-digest.sh' for content." >&2
	exit 2
fi

# === BLOCK: PRISMA/DRIZZLE ===
# Allow: migrate dev --create-only (creates SQL file, minimal output)
# Allow: migrate diff (read-only comparison, no DB changes)
if echo "$COMMAND" | grep -qE "prisma migrate (dev.*--create-only|diff)"; then
	exit 0
fi
if echo "$BASE_CMD" | grep -qE "^npx (prisma|drizzle-kit) (migrate|db push|generate|check)"; then
	echo "TOKEN-WASTE: Use 'migration-digest.sh' instead." >&2
	echo "  For new migrations: npx prisma migrate dev --name <name> --create-only" >&2
	exit 2
fi

# === BLOCK: GIT STATUS / LOG ===
if echo "$BASE_CMD" | grep -qE "^git status( |$)"; then
	echo "TOKEN-WASTE: Use 'git-digest.sh' instead (status+branch+log in ONE call)." >&2
	exit 2
fi
if echo "$BASE_CMD" | grep -qE "^git log( |$)" && ! echo "$COMMAND" | grep -qE "\-\-(oneline|format)"; then
	echo "TOKEN-WASTE: Use 'git-digest.sh' (includes last 5 commits)." >&2
	exit 2
fi

exit 0
