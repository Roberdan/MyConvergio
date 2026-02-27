#!/usr/bin/env bash
# spotlight-exclude.sh - Drop .metadata_never_index in build/cache/deps directories
# Prevents macOS Spotlight from indexing waste (saves CPU, battery, I/O)
# Usage: spotlight-exclude.sh [path...] [--dry-run] [--worktree-cleanup]
# Version: 1.0.0
set -euo pipefail

DRY_RUN=0
CLEANUP_WORKTREES=0
PATHS=()

for arg in "$@"; do
	case "$arg" in
	--dry-run) DRY_RUN=1 ;;
	--worktree-cleanup) CLEANUP_WORKTREES=1 ;;
	*) PATHS+=("$arg") ;;
	esac
done

# Default: scan known project roots
if [[ ${#PATHS[@]} -eq 0 ]]; then
	PATHS=(
		"$HOME/.claude"
		"$HOME/GitHub/MyConvergio"
	)
fi

# Directories that should never be indexed
EXCLUDE_NAMES=(
	node_modules .next .turbo dist .output .vercel
	coverage .cache .parcel-cache
	__pycache__ .pytest_cache .mypy_cache .ruff_cache
	.codegraph
)

# Build find expression
FIND_EXPR=()
for i in "${!EXCLUDE_NAMES[@]}"; do
	[[ $i -gt 0 ]] && FIND_EXPR+=("-o")
	FIND_EXPR+=("-name" "${EXCLUDE_NAMES[$i]}")
done

COUNT=0
for base in "${PATHS[@]}"; do
	[[ -d "$base" ]] || continue
	while IFS= read -r dir; do
		marker="$dir/.metadata_never_index"
		if [[ ! -f "$marker" ]]; then
			if [[ "$DRY_RUN" -eq 1 ]]; then
				echo "[dry-run] $marker"
			else
				touch "$marker"
			fi
			COUNT=$((COUNT + 1))
		fi
	done < <(find "$base" -maxdepth 5 -type d \( "${FIND_EXPR[@]}" \) -prune 2>/dev/null)
done

# Stale worktree cleanup (--worktree-cleanup)
if [[ "$CLEANUP_WORKTREES" -eq 1 ]]; then
	while IFS= read -r wt; do
		[[ -d "$wt" ]] || continue
		marker="$wt/.metadata_never_index"
		if [[ ! -f "$marker" ]]; then
			if [[ "$DRY_RUN" -eq 1 ]]; then
				echo "[dry-run] $marker (stale worktree)"
			else
				touch "$marker"
			fi
			COUNT=$((COUNT + 1))
		fi
	done < <(find "$HOME/GitHub" -maxdepth 1 -name "*-plan-*" -type d 2>/dev/null)
fi

echo "{\"excluded\":$COUNT,\"dry_run\":$DRY_RUN}"
