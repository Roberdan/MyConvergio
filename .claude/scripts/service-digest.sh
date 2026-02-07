#!/usr/bin/env bash
# Service Digest - Unified entry point for all service digests
# Single call for CI + PR + Deploy status. Minimal tokens.
# Usage: service-digest.sh <ci|pr|deploy|all> [args...] [--no-cache]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
ci)
	"$SCRIPT_DIR/ci-digest.sh" "$@"
	;;
pr)
	"$SCRIPT_DIR/pr-digest.sh" "$@"
	;;
deploy)
	"$SCRIPT_DIR/deploy-digest.sh" "$@"
	;;
all)
	# Run all three in parallel, combine results
	TMPDIR_ALL=$(mktemp -d)
	trap "rm -rf '$TMPDIR_ALL'" EXIT

	"$SCRIPT_DIR/ci-digest.sh" "$@" >"$TMPDIR_ALL/ci.json" 2>/dev/null &
	PID_CI=$!
	"$SCRIPT_DIR/pr-digest.sh" "$@" >"$TMPDIR_ALL/pr.json" 2>/dev/null &
	PID_PR=$!
	"$SCRIPT_DIR/deploy-digest.sh" "$@" >"$TMPDIR_ALL/deploy.json" 2>/dev/null &
	PID_DEPLOY=$!

	wait "$PID_CI" 2>/dev/null || true
	wait "$PID_PR" 2>/dev/null || true
	wait "$PID_DEPLOY" 2>/dev/null || true

	# Combine into single JSON
	CI_JSON=$(cat "$TMPDIR_ALL/ci.json" 2>/dev/null || echo '{}')
	PR_JSON=$(cat "$TMPDIR_ALL/pr.json" 2>/dev/null || echo '{}')
	DEPLOY_JSON=$(cat "$TMPDIR_ALL/deploy.json" 2>/dev/null || echo '{}')

	jq -n \
		--argjson ci "$CI_JSON" \
		--argjson pr "$PR_JSON" \
		--argjson deploy "$DEPLOY_JSON" \
		'{ci:$ci,pr:$pr,deploy:$deploy}'
	;;
flush)
	digest_cache_flush
	echo '{"cache":"flushed"}'
	;;
help | *)
	cat <<'EOF'
Service Digest - Token-efficient service status for AI agents

Usage: service-digest.sh <command> [args] [--no-cache]

Commands:
  ci [run-id|--all]         CI run status + errors (JSON)
  pr [pr-number]            PR reviews + unresolved comments (JSON)
  deploy [deployment-url]   Vercel deployment status (JSON)
  all                       All three in parallel, combined JSON
  flush                     Clear all cached digests

Options:
  --no-cache    Skip cache, fetch fresh data

Examples:
  service-digest.sh ci                 # CI for current branch
  service-digest.sh pr 123             # PR #123 review digest
  service-digest.sh all                # Everything in one call
  service-digest.sh all --no-cache     # Fresh data, no cache
EOF
	;;
esac
