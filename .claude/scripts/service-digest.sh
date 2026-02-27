#!/usr/bin/env bash
# Service Digest - Unified entry point for all service digests
# Single call for CI + PR + Deploy status. Minimal tokens.
# Usage: service-digest.sh <ci|pr|deploy|all> [args...] [--no-cache] [--compact]
# Version: 1.2.0
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
sentry)
	"$SCRIPT_DIR/sentry-digest.sh" "$@"
	;;
copilot)
	"$SCRIPT_DIR/copilot-review-digest.sh" "$@"
	;;
all)
	# Run all three in parallel, combine results
	TMPDIR_ALL=$(mktemp -d)
	trap "rm -rf '$TMPDIR_ALL'" EXIT

	"$SCRIPT_DIR/ci-digest.sh" "$@" >"$TMPDIR_ALL/ci.json" 2>"$TMPDIR_ALL/ci.err" &
	PID_CI=$!
	"$SCRIPT_DIR/pr-digest.sh" "$@" >"$TMPDIR_ALL/pr.json" 2>"$TMPDIR_ALL/pr.err" &
	PID_PR=$!
	"$SCRIPT_DIR/deploy-digest.sh" "$@" >"$TMPDIR_ALL/deploy.json" 2>"$TMPDIR_ALL/deploy.err" &
	PID_DEPLOY=$!
	"$SCRIPT_DIR/sentry-digest.sh" list "$@" >"$TMPDIR_ALL/sentry.json" 2>"$TMPDIR_ALL/sentry.err" &
	PID_SENTRY=$!
	"$SCRIPT_DIR/copilot-review-digest.sh" "$@" >"$TMPDIR_ALL/copilot.json" 2>"$TMPDIR_ALL/copilot.err" &
	PID_COPILOT=$!

	wait "$PID_CI" 2>/dev/null || true
	wait "$PID_PR" 2>/dev/null || true
	wait "$PID_DEPLOY" 2>/dev/null || true
	wait "$PID_SENTRY" 2>/dev/null || true
	wait "$PID_COPILOT" 2>/dev/null || true

	# Combine into single JSON (include stderr as error field if sub-script produced no JSON)
	CI_JSON=$(cat "$TMPDIR_ALL/ci.json" 2>/dev/null || echo '{}')
	PR_JSON=$(cat "$TMPDIR_ALL/pr.json" 2>/dev/null || echo '{}')
	DEPLOY_JSON=$(cat "$TMPDIR_ALL/deploy.json" 2>/dev/null || echo '{}')
	SENTRY_JSON=$(cat "$TMPDIR_ALL/sentry.json" 2>/dev/null || echo '{}')
	COPILOT_JSON=$(cat "$TMPDIR_ALL/copilot.json" 2>/dev/null || echo '{}')

	# If a sub-script failed and produced no valid JSON, include stderr
	if ! echo "$CI_JSON" | jq empty 2>/dev/null && [[ -s "$TMPDIR_ALL/ci.err" ]]; then
		CI_JSON=$(jq -n --arg msg "$(head -3 "$TMPDIR_ALL/ci.err" | tr '\n' ' ' | cut -c1-200)" \
			'{"status":"script_error","msg":$msg}')
	fi
	if ! echo "$PR_JSON" | jq empty 2>/dev/null && [[ -s "$TMPDIR_ALL/pr.err" ]]; then
		PR_JSON=$(jq -n --arg msg "$(head -3 "$TMPDIR_ALL/pr.err" | tr '\n' ' ' | cut -c1-200)" \
			'{"status":"script_error","msg":$msg}')
	fi
	if ! echo "$DEPLOY_JSON" | jq empty 2>/dev/null && [[ -s "$TMPDIR_ALL/deploy.err" ]]; then
		DEPLOY_JSON=$(jq -n --arg msg "$(head -3 "$TMPDIR_ALL/deploy.err" | tr '\n' ' ' | cut -c1-200)" \
			'{"status":"script_error","msg":$msg}')
	fi
	if ! echo "$SENTRY_JSON" | jq empty 2>/dev/null && [[ -s "$TMPDIR_ALL/sentry.err" ]]; then
		SENTRY_JSON=$(jq -n --arg msg "$(head -3 "$TMPDIR_ALL/sentry.err" | tr '\n' ' ' | cut -c1-200)" \
			'{"status":"script_error","msg":$msg}')
	fi
	if ! echo "$COPILOT_JSON" | jq empty 2>/dev/null && [[ -s "$TMPDIR_ALL/copilot.err" ]]; then
		COPILOT_JSON=$(jq -n --arg msg "$(head -3 "$TMPDIR_ALL/copilot.err" | tr '\n' ' ' | cut -c1-200)" \
			'{"status":"script_error","msg":$msg}')
	fi

	jq -n \
		--argjson ci "$CI_JSON" \
		--argjson pr "$PR_JSON" \
		--argjson deploy "$DEPLOY_JSON" \
		--argjson sentry "$SENTRY_JSON" \
		--argjson copilot "$COPILOT_JSON" \
		'{ci:$ci,pr:$pr,deploy:$deploy,sentry:$sentry,copilot:$copilot}'
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
  sentry [list|resolve id]  Sentry unresolved issues (JSON)
  copilot [pr-number]       Copilot bot review comments digest (JSON)
  all                       All five in parallel, combined JSON
  flush                     Clear all cached digests

Options:
  --no-cache    Skip cache, fetch fresh data
  --compact     Omit non-essential fields (~30-40% fewer tokens)

Examples:
  service-digest.sh ci                 # CI for current branch
  service-digest.sh pr 123             # PR #123 review digest
  service-digest.sh all                # Everything in one call
  service-digest.sh all --no-cache     # Fresh data, no cache
EOF
	;;
esac
