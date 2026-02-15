#!/usr/bin/env bash
# Sentry Digest - Compact Sentry issues status as JSON (~200 tokens)
# Lists unresolved issues with counts. Can resolve issues by ID.
# Usage: sentry-digest.sh [list|resolve <id>...] [--no-cache]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=120
NO_CACHE=0

# Parse --no-cache from any position
for arg in "$@"; do
	[[ "$arg" == "--no-cache" ]] && NO_CACHE=1
done

# First non-flag arg is the command
CMD="list"
for arg in "$@"; do
	[[ "$arg" != "--no-cache" ]] && {
		CMD="$arg"
		break
	}
done

# Find sentry-cli and credentials
find_sentry_cli() {
	local cli=""
	if command -v sentry-cli &>/dev/null; then
		cli="sentry-cli"
	elif [[ -f "./node_modules/@sentry/cli/bin/sentry-cli" ]]; then
		cli="./node_modules/@sentry/cli/bin/sentry-cli"
	elif [[ -f "node_modules/.bin/sentry-cli" ]]; then
		cli="node_modules/.bin/sentry-cli"
	fi
	echo "$cli"
}

load_sentry_env() {
	local env_file=""
	for f in .env .env.local .env.production; do
		[[ -f "$f" ]] && env_file="$f" && break
	done
	[[ -z "$env_file" ]] && return 1

	SENTRY_ORG=$(grep '^SENTRY_ORG=' "$env_file" | cut -d= -f2- | tr -d '"' || true)
	SENTRY_PROJECT=$(grep '^SENTRY_PROJECT=' "$env_file" | cut -d= -f2- | tr -d '"' || true)
	export SENTRY_AUTH_TOKEN
	SENTRY_AUTH_TOKEN=$(grep '^SENTRY_AUTH_TOKEN=' "$env_file" | cut -d= -f2- | tr -d '"' || true)

	[[ -z "$SENTRY_ORG" || -z "$SENTRY_PROJECT" || -z "$SENTRY_AUTH_TOKEN" ]] && return 1
	return 0
}

SENTRY_CLI=$(find_sentry_cli)
if [[ -z "$SENTRY_CLI" ]]; then
	jq -n '{"status":"no_cli","msg":"sentry-cli not found"}'
	exit 0
fi

if ! load_sentry_env; then
	jq -n '{"status":"no_config","msg":"SENTRY_ORG/PROJECT/AUTH_TOKEN not found in .env"}'
	exit 0
fi

case "$CMD" in
list)
	CACHE_KEY="sentry-${SENTRY_ORG}-${SENTRY_PROJECT}"
	if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
		exit 0
	fi

	# Get all issues (sentry-cli -s flag is unreliable, filter manually)
	RAW=$("$SENTRY_CLI" issues list \
		--org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
		2>/dev/null || echo "")

	# Parse table output into JSON, filtering for unresolved only
	UNRESOLVED=0
	ISSUES="[]"
	if [[ -n "$RAW" ]] && echo "$RAW" | grep -q '|'; then
		ISSUES=$(echo "$RAW" | grep '|' | grep -v '^+' | grep -v 'Issue ID' |
			while IFS='|' read -r _ id short title lastseen status level _; do
				id=$(echo "$id" | xargs)
				short=$(echo "$short" | xargs)
				title=$(echo "$title" | xargs | cut -c1-100)
				status=$(echo "$status" | xargs)
				level=$(echo "$level" | xargs)
				[[ -z "$id" ]] && continue
				# Only include unresolved issues
				[[ "$status" != "unresolved" ]] && continue
				jq -n --arg id "$id" --arg short "$short" \
					--arg title "$title" --arg level "$level" \
					'{id:$id,short:$short,title:$title,level:$level}'
			done | jq -s '.')
		UNRESOLVED=$(echo "$ISSUES" | jq 'length')
	fi

	RESULT=$(jq -n \
		--arg org "$SENTRY_ORG" \
		--arg project "$SENTRY_PROJECT" \
		--argjson count "$UNRESOLVED" \
		--argjson issues "$ISSUES" \
		'{status:"ok",org:$org,project:$project,unresolved:$count,issues:$issues}')

	echo "$RESULT" | digest_cache_set "$CACHE_KEY"
	echo "$RESULT"
	;;
resolve)
	shift
	IDS=()
	for arg in "$@"; do
		[[ "$arg" != "--no-cache" ]] && IDS+=("$arg")
	done

	if [[ ${#IDS[@]} -eq 0 ]]; then
		jq -n '{"status":"error","msg":"No issue IDs provided"}'
		exit 1
	fi

	ID_ARGS=()
	for id in "${IDS[@]}"; do
		ID_ARGS+=(-i "$id")
	done

	"$SENTRY_CLI" issues resolve \
		--org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
		"${ID_ARGS[@]}" 2>/dev/null

	# Invalidate cache
	digest_cache_clear "sentry-${SENTRY_ORG}-${SENTRY_PROJECT}"

	jq -n --argjson count "${#IDS[@]}" \
		'{status:"resolved",count:$count}'
	;;
help | *)
	cat <<'HELP'
Sentry Digest - Token-efficient Sentry issue status

Usage: sentry-digest.sh <command> [args] [--no-cache]

Commands:
  list                    List unresolved issues (JSON)
  resolve <id> [id...]    Resolve issues by ID

Requires: SENTRY_ORG, SENTRY_PROJECT, SENTRY_AUTH_TOKEN in .env
HELP
	;;
esac
