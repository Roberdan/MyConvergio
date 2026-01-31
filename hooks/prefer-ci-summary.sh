#!/usr/bin/env bash
# prefer-ci-summary.sh - PreToolUse hook on Bash
# Intercepts verbose commands and suggests token-efficient alternatives.
# Saves ~70-95% tokens per verification cycle.
#
# Hook type: PreToolUse on Bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Allow our optimized scripts (digest, ci-summary, ci-check)
echo "$COMMAND" | grep -qE "digest\.sh|ci-summary|ci-check|service-digest" && exit 0

# Allow release/pre-push scripts (they have their own filtering)
echo "$COMMAND" | grep -qE "release|pre-push|pre-release" && exit 0

# Allow piped commands (user is already filtering)
echo "$COMMAND" | grep -qE "\|.*grep|\|.*head|\|.*tail|\|.*wc" && exit 0

# Allow commands with --reporter, --format, --oneline, --short, --stat
echo "$COMMAND" | grep -qE "\-\-(reporter|format|oneline|short|stat)" && exit 0

# === CI LOGS ===
# Block: gh run view --log / --log-failed (dumps entire log)
if echo "$COMMAND" | grep -qE "gh run view.*--log"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh ci <run-id>' instead." >&2
	echo "ci-digest.sh processes logs server-side, returns ~200 tokens JSON." >&2
	exit 2
fi

# === PR COMMENTS ===
# Block: gh pr view --comments (dumps all comments including bots)
if echo "$COMMAND" | grep -qE "gh pr view.*--comments"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh pr <pr-number>' instead." >&2
	echo "pr-digest.sh filters bots, returns only human unresolved threads." >&2
	exit 2
fi

# Block: gh api .../pulls/.../comments (raw API dump)
if echo "$COMMAND" | grep -qE "gh api.*pulls/[0-9]+/comments"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh pr <pr-number>' instead." >&2
	echo "pr-digest.sh filters bots, returns only human unresolved threads." >&2
	exit 2
fi

# Block: gh api .../pulls/.../reviews (raw API dump)
if echo "$COMMAND" | grep -qE "gh api.*pulls/[0-9]+/reviews"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh pr <pr-number>' instead." >&2
	echo "pr-digest.sh includes review decisions in compact format." >&2
	exit 2
fi

# Allow other gh commands (gh pr create, gh pr list, etc.)
echo "$COMMAND" | grep -qE "^gh " && exit 0

# === VERCEL LOGS ===
# Block: vercel logs (raw deployment log dump)
if echo "$COMMAND" | grep -qE "^vercel logs"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh deploy' instead." >&2
	echo "deploy-digest.sh returns status + errors only, no raw build log." >&2
	exit 2
fi

# Block: vercel-helper.sh logs (same via wrapper)
if echo "$COMMAND" | grep -qE "vercel-helper\.sh logs"; then
	echo "TOKEN-WASTE: Use 'service-digest.sh deploy' instead." >&2
	echo "deploy-digest.sh returns status + errors only, no raw build log." >&2
	exit 2
fi

# === NPM INSTALL ===
# Block: npm install / npm ci (massive output)
if echo "$COMMAND" | grep -qE "^npm (install|ci)( |$)"; then
	echo "TOKEN-WASTE: Use 'npm-digest.sh install' or 'npm-digest.sh ci' instead." >&2
	echo "npm-digest.sh captures output server-side, returns compact JSON summary." >&2
	exit 2
fi

# === NPM AUDIT ===
if echo "$COMMAND" | grep -qE "^npm audit( |$)" && ! echo "$COMMAND" | grep -q "\-\-json"; then
	echo "TOKEN-WASTE: Use 'audit-digest.sh' instead of raw npm audit." >&2
	echo "audit-digest.sh returns only critical/high items as JSON." >&2
	exit 2
fi

# === BUILD ===
# Block: npm run build (verbose webpack/next output)
if echo "$COMMAND" | grep -qE "^npm run build( |$)"; then
	echo "TOKEN-WASTE: Use 'build-digest.sh' instead of raw npm run build." >&2
	echo "build-digest.sh returns status + errors + bundle_size as JSON." >&2
	exit 2
fi

# === TESTS ===
# Block: raw test invocations
if echo "$COMMAND" | grep -qE "^(npx (vitest|jest|playwright)|npm run test|npm test)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "TOKEN-WASTE: Use './scripts/ci-summary.sh --unit|--e2e' instead." >&2
	else
		echo "TOKEN-WASTE: Use 'test-digest.sh' instead of raw test runner." >&2
		echo "test-digest.sh returns only failures as JSON." >&2
	fi
	exit 2
fi

# === VERBOSE NPM CI COMMANDS (lint/typecheck via ci-summary) ===
if echo "$COMMAND" | grep -qE "^npm run (lint|typecheck|test:unit)( |$)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "TOKEN-WASTE: Use './scripts/ci-summary.sh' instead." >&2
		echo "Steps: --lint|--types|--build|--unit|--i18n|--e2e|--a11y|--full|--all" >&2
		exit 0
	fi
fi

# === CHAINED VERBOSE COMMANDS ===
if echo "$COMMAND" | grep -qE "npm run lint.*&&.*npm run (typecheck|build)"; then
	if [ -f "./scripts/ci-summary.sh" ]; then
		echo "TOKEN-WASTE: Use 'npm run ci:summary' instead of chained commands." >&2
		exit 0
	fi
fi

# === GIT DIFF (large) ===
# Block: raw git diff without --stat (can be thousands of lines)
if echo "$COMMAND" | grep -qE "^git diff [^-]"; then
	echo "TOKEN-WASTE: Use 'diff-digest.sh' for large diffs." >&2
	echo "diff-digest.sh returns file list + size breakdown as JSON." >&2
	echo "Then use Read tool on specific files." >&2
	exit 2
fi

# === PRISMA/DRIZZLE MIGRATIONS ===
if echo "$COMMAND" | grep -qE "^npx (prisma|drizzle-kit) (migrate|db push|generate|check)"; then
	echo "TOKEN-WASTE: Use 'migration-digest.sh [status|push|generate]' instead." >&2
	echo "migration-digest.sh returns tables + destructive changes as JSON." >&2
	exit 2
fi

# === VERBOSE GIT LOG ===
if echo "$COMMAND" | grep -qE "^git log[^|]*$" && ! echo "$COMMAND" | grep -q "oneline"; then
	echo "TOKEN-HINT: Use 'git log --oneline -N' to reduce output." >&2
	exit 0
fi

exit 0
