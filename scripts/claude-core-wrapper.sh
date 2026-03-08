#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

resolve_platform_artifact() {
	local os arch
	os="$(uname -s | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
	case "$arch" in
	arm64) arch="aarch64" ;;
	amd64) arch="x86_64" ;;
	esac
	printf '%s/rust/claude-core/target/release/claude-core-%s-%s\n' "$REPO_ROOT" "$os" "$arch"
}

resolve_claude_core() {
	if [[ -n "${CLAUDE_CORE_BIN:-}" && -x "${CLAUDE_CORE_BIN}" ]]; then
		printf '%s\n' "$CLAUDE_CORE_BIN"
		return 0
	fi

	if command -v claude-core >/dev/null 2>&1; then
		command -v claude-core
		return 0
	fi

	local local_release="$REPO_ROOT/rust/claude-core/target/release/claude-core"
	if [[ -x "$local_release" ]]; then
		printf '%s\n' "$local_release"
		return 0
	fi

	local platform_artifact
	platform_artifact="$(resolve_platform_artifact)"
	if [[ -x "$platform_artifact" ]]; then
		printf '%s\n' "$platform_artifact"
		return 0
	fi

	return 1
}

run_plan() {
	local core_bin
	if core_bin="$(resolve_claude_core)"; then
		exec "$core_bin" db "$@"
	fi
	exec "$REPO_ROOT/scripts/plan-db.sh" "$@"
}

run_hook() {
	local core_bin
	if core_bin="$(resolve_claude_core)"; then
		exec "$core_bin" hooks "$@"
	fi
	exec "$REPO_ROOT/hooks/dispatcher.sh" "$@"
}

usage() {
	cat <<'EOF'
Usage: claude-core-wrapper.sh <plan|hook> [args...]

Commands:
  plan ...        Run plan-db commands through claude-core db when available.
  hook ...        Run hook dispatcher through claude-core hooks when available.
EOF
}

main() {
	local command="${1:-}"
	case "$command" in
	plan)
		shift
		run_plan "$@"
		;;
	hook | hooks | dispatcher)
		shift
		run_hook "$@"
		;;
	"" | -h | --help | help)
		usage
		;;
	*)
		echo "Unknown command: $command" >&2
		usage >&2
		exit 2
		;;
	esac
}

main "$@"
