#!/usr/bin/env bash
# prefer-ci-summary.sh - PreToolUse hook on Bash
# Intercepts verbose commands → suggests token-efficient alternatives.
# Block = exit 2. Hint = exit 0.
# Version: 1.4.0
#
# Block rules check BASE_CMD (before pipe), so
# "gh run view --log-failed | tail -200" is STILL blocked.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Extract LAST command in chain (after && or ;), before any pipe
BASE_CMD=$(echo "$COMMAND" | sed 's/|.*//' | sed 's/.*&&//' | sed 's/.*;//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# === ALWAYS ALLOW: our optimized scripts ===
echo "$COMMAND" | grep -qE "digest\.sh|service-digest|pr-ops\.sh|code-pattern-check\.sh" && exit 0
echo "$COMMAND" | grep -qE "ci-summary\.sh --(quick|full|all|lint|types|build|unit|i18n|e2e|a11y)" && exit 0
echo "$COMMAND" | grep -qE "(\./scripts/|npm run )(release|pre-push|pre-release)" && exit 0

# === HINT: wc -l ===
if echo "$COMMAND" | grep -qE "wc -l" && ! echo "$BASE_CMD" | grep -qE "^git (commit|tag)"; then
	echo "Hint: grep -c . <file>" >&2
	exit 0
fi

# === BLOCK: CI LOGS ===
echo "$BASE_CMD" | grep -qE "gh run view.*--log" && {
	echo "Use: service-digest.sh ci <run-id>" >&2
	exit 2
}

# === BLOCK: PR COMMENTS (read only, allow writes) ===
echo "$BASE_CMD" | grep -qE "gh pr view.*--comments" && {
	echo "Use: service-digest.sh pr <pr>" >&2
	exit 2
}
if echo "$BASE_CMD" | grep -qE "gh api.*pulls/[0-9]+/(comments|reviews)"; then
	echo "$COMMAND" | grep -qE " -[fF] | --method | -X " || {
		echo "Use: service-digest.sh pr <pr>" >&2
		exit 2
	}
	echo "$COMMAND" | grep -qE " -[fF] | -X " && {
		echo "Hint: pr-ops.sh reply <pr> <id> \"msg\"" >&2
		exit 0
	}
fi

# === BLOCK: PR MERGE ===
echo "$BASE_CMD" | grep -qE "^gh pr merge" && {
	echo "Use: pr-ops.sh merge <pr>" >&2
	exit 2
}

# === BLOCK: PR VIEW (verbose) ===
if echo "$BASE_CMD" | grep -qE "^gh pr view" && ! echo "$COMMAND" | grep -qE "\-\-json"; then
	echo "Use: pr-ops.sh status <pr>" >&2
	exit 2
fi

# === BLOCK: PR CHECKS ===
echo "$BASE_CMD" | grep -qE "^gh pr checks" && {
	echo "Use: ci-digest.sh checks <pr>" >&2
	exit 2
}

# Allow other gh commands
echo "$BASE_CMD" | grep -qE "^gh " && exit 0

# === BLOCK: VERCEL LOGS ===
echo "$BASE_CMD" | grep -qE "(^vercel logs|vercel-helper\.sh logs)" && {
	echo "Use: service-digest.sh deploy" >&2
	exit 2
}

# === BLOCK: NPM INSTALL ===
echo "$BASE_CMD" | grep -qE "^npm (install|ci)( |$)" && {
	echo "Use: npm-digest.sh install" >&2
	exit 2
}

# === BLOCK: NPM AUDIT ===
if echo "$BASE_CMD" | grep -qE "^npm audit( |$)" && ! echo "$COMMAND" | grep -q "\-\-json"; then
	echo "Use: audit-digest.sh" >&2
	exit 2
fi

# === BLOCK: BUILD ===
echo "$BASE_CMD" | grep -qE "^npm run build( |$)" && {
	echo "Use: build-digest.sh" >&2
	exit 2
}

# === BLOCK: TESTS ===
if echo "$BASE_CMD" | grep -qE "^(npx (vitest|jest|playwright)|npm run test|npm test)( |$)"; then
	[ -f "./scripts/ci-summary.sh" ] && echo "Use: ./scripts/ci-summary.sh --unit|--e2e" >&2 || echo "Use: test-digest.sh" >&2
	exit 2
fi

# === BLOCK: VERBOSE NPM (lint/typecheck) ===
if echo "$BASE_CMD" | grep -qE "^npm run (lint|typecheck|test:unit)( |$)"; then
	[ -f "./scripts/ci-summary.sh" ] && echo "Use: ./scripts/ci-summary.sh --quick" >&2 || echo "Use: test-digest.sh" >&2
	exit 2
fi

# === HINT: ci:summary → suggest --quick ===
if echo "$BASE_CMD" | grep -qE "^(npm run ci:summary|\\./scripts/ci-summary\\.sh)( |$)"; then
	[ -f "./scripts/ci-summary.sh" ] && {
		echo "Hint: ci-summary.sh --quick (faster)" >&2
		exit 0
	}
fi

# === BLOCK: GIT DIFF (except --stat) ===
if echo "$BASE_CMD" | grep -qE "^git diff"; then
	echo "$BASE_CMD" | grep -qE "^git diff --stat( |$)" && exit 0
	echo "Use: git-digest.sh --full or diff-digest.sh" >&2
	exit 2
fi

# === BLOCK: PRISMA/DRIZZLE ===
echo "$COMMAND" | grep -qE "prisma migrate (dev.*--create-only|diff)" && exit 0
if echo "$BASE_CMD" | grep -qE "^npx (prisma|drizzle-kit) (migrate|db push|generate|check)"; then
	echo "Use: migration-digest.sh" >&2
	exit 2
fi

# === BLOCK: GIT STATUS / LOG ===
echo "$BASE_CMD" | grep -qE "^git status( |$)" && {
	echo "Use: git-digest.sh" >&2
	exit 2
}
if echo "$BASE_CMD" | grep -qE "^git log( |$)" && ! echo "$COMMAND" | grep -qE "\-\-(oneline|format)"; then
	echo "Use: git-digest.sh" >&2
	exit 2
fi

# === BLOCK: GIT SHOW (verbose) ===
if echo "$BASE_CMD" | grep -qE "^git show( |$)" && ! echo "$COMMAND" | grep -qE "\-\-(oneline|format|stat)"; then
	echo "Use: git log --oneline --stat <sha> -1" >&2
	exit 2
fi

exit 0
