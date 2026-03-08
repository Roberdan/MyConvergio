#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

usage() {
	cat <<'EOF'
Unified digest dispatcher

Usage: digest.sh <subcommand> [args...]

Subcommands:
  audit           -> audit-digest.sh
  build           -> build-digest.sh
  ci              -> ci-digest.sh
  copilot-review  -> copilot-review-digest.sh
  db              -> db-digest.sh
  deploy          -> deploy-digest.sh
  diff            -> diff-digest.sh
  error           -> error-digest.sh
  git             -> git-digest.sh
  merge           -> merge-digest.sh
  migration       -> migration-digest.sh
  npm             -> npm-digest.sh
  pr              -> pr-digest.sh
  sentry          -> sentry-digest.sh
  service         -> service-digest.sh
  test            -> test-digest.sh
EOF
}

run_module() {
	local module_path="$1"
	shift
	[[ -f "$module_path" ]] || {
		echo "digest.sh: module not found: $module_path" >&2
		exit 1
	}

	# Lazy-source only the requested module. Exit calls remain scoped to this subshell.
	(
		source "$module_path" "$@"
	)
}

cmd="${1:-help}"
if [[ $# -gt 0 ]]; then
	shift
fi

case "$cmd" in
audit)
	run_module "$SCRIPT_DIR/audit-digest.sh" "$@"
	;;
build)
	run_module "$SCRIPT_DIR/build-digest.sh" "$@"
	;;
ci)
	run_module "$SCRIPT_DIR/ci-digest.sh" "$@"
	;;
copilot-review)
	run_module "$SCRIPT_DIR/copilot-review-digest.sh" "$@"
	;;
db)
	run_module "$SCRIPT_DIR/db-digest.sh" "$@"
	;;
deploy)
	run_module "$SCRIPT_DIR/deploy-digest.sh" "$@"
	;;
diff)
	run_module "$SCRIPT_DIR/diff-digest.sh" "$@"
	;;
error)
	run_module "$SCRIPT_DIR/error-digest.sh" "$@"
	;;
git)
	run_module "$SCRIPT_DIR/git-digest.sh" "$@"
	;;
merge)
	run_module "$SCRIPT_DIR/merge-digest.sh" "$@"
	;;
migration)
	run_module "$SCRIPT_DIR/migration-digest.sh" "$@"
	;;
npm)
	run_module "$SCRIPT_DIR/npm-digest.sh" "$@"
	;;
pr)
	run_module "$SCRIPT_DIR/pr-digest.sh" "$@"
	;;
sentry)
	run_module "$SCRIPT_DIR/sentry-digest.sh" "$@"
	;;
service)
	run_module "$SCRIPT_DIR/service-digest.sh" "$@"
	;;
test)
	run_module "$SCRIPT_DIR/test-digest.sh" "$@"
	;;
help | --help | -h)
	usage
	;;
*)
	echo "digest.sh: unknown subcommand '$cmd'" >&2
	usage >&2
	exit 1
	;;
esac
