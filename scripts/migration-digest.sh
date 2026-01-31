#!/usr/bin/env bash
# Migration Digest - Compact Prisma/Drizzle migration output as JSON
# Usage: migration-digest.sh [status|push|generate|diff] [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CACHE_TTL=60
NO_CACHE=0
CMD="${1:-status}"

[[ "$CMD" == "--no-cache" ]] && {
	NO_CACHE=1
	CMD="${2:-status}"
}
[[ "${2:-}" == "--no-cache" ]] && NO_CACHE=1

# Detect ORM
ORM="unknown"
if [[ -f "prisma/schema.prisma" ]]; then
	ORM="prisma"
elif [[ -f "drizzle.config.ts" || -f "drizzle.config.js" ]]; then
	ORM="drizzle"
fi

if [[ "$ORM" == "unknown" ]]; then
	jq -n '{"orm":"unknown","status":"no_orm_detected","msg":"No prisma or drizzle config found"}'
	exit 0
fi

CACHE_KEY="migration-${ORM}-${CMD}-$(pwd | md5sum 2>/dev/null | cut -c1-8 || echo 'x')"

if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
	exit 0
fi

TMPLOG=$(mktemp)
trap "rm -f '$TMPLOG'" EXIT

EXIT_CODE=0

if [[ "$ORM" == "prisma" ]]; then
	case "$CMD" in
	status)
		npx prisma migrate status >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	push)
		npx prisma db push >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	generate)
		npx prisma generate >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	diff)
		npx prisma migrate diff --from-schema-datamodel prisma/schema.prisma \
			--to-schema-datasource prisma/schema.prisma >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	*)
		jq -n --arg cmd "$CMD" '{"error":"unknown command","cmd":$cmd}'
		exit 1
		;;
	esac
elif [[ "$ORM" == "drizzle" ]]; then
	case "$CMD" in
	status)
		npx drizzle-kit check >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	push)
		npx drizzle-kit push >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	generate)
		npx drizzle-kit generate >"$TMPLOG" 2>&1 || EXIT_CODE=$?
		;;
	*)
		jq -n --arg cmd "$CMD" '{"error":"unknown command","cmd":$cmd}'
		exit 1
		;;
	esac
fi

STATUS="ok"
[[ "$EXIT_CODE" -ne 0 ]] && STATUS="error"

# Extract tables/models mentioned
TABLES=$(grep -ioE '(CREATE|ALTER|DROP)\s+TABLE\s+\S+|model\s+\w+' "$TMPLOG" |
	sed 's/model //' |
	sort -u |
	jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")

# Extract warnings about destructive changes
DESTRUCTIVE=$(grep -iE 'drop|delete|remove|destructive|data loss|truncate' "$TMPLOG" |
	head -5 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:200])' 2>/dev/null || echo "[]")

# Extract errors
ERRORS=$(grep -iE 'error|failed|P[0-9]{4}|constraint' "$TMPLOG" |
	head -5 |
	jq -R -s 'split("\n") | map(select(length > 0)) | map(.[0:200])' 2>/dev/null || echo "[]")

# Migration count (prisma)
PENDING=0
APPLIED=0
if [[ "$ORM" == "prisma" && "$CMD" == "status" ]]; then
	PENDING=$(grep -coE 'not yet applied' "$TMPLOG" 2>/dev/null) || PENDING=0
	APPLIED=$(grep -coE 'applied migration' "$TMPLOG" 2>/dev/null) || APPLIED=0
fi

RESULT=$(jq -n \
	--arg orm "$ORM" \
	--arg cmd "$CMD" \
	--arg status "$STATUS" \
	--argjson exit_code "$EXIT_CODE" \
	--argjson tables "$TABLES" \
	--argjson destructive "$DESTRUCTIVE" \
	--argjson errors "$ERRORS" \
	--argjson pending "$PENDING" \
	--argjson applied "$APPLIED" \
	'{orm:$orm, cmd:$cmd, status:$status, exit_code:$exit_code,
	  tables:$tables, pending:$pending, applied:$applied,
	  destructive:$destructive, errors:$errors}')

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT"
