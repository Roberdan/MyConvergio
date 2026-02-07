#!/usr/bin/env bash
# Merge Digest - Extract git conflict blocks as compact JSON
# One call replaces N file reads during conflict resolution.
# Usage: merge-digest.sh [--rebase] [branch]
#   After a failed merge/rebase, run this to get structured conflicts.
#   Without args: scans working tree for conflict markers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

MODE="merge"
BRANCH=""
[[ "${1:-}" == "--rebase" ]] && {
	MODE="rebase"
	shift
}
BRANCH="${1:-}"

# Check for conflict state
IN_MERGE=$(git rev-parse --git-dir 2>/dev/null)/MERGE_HEAD
IN_REBASE=$(git rev-parse --git-dir 2>/dev/null)/rebase-merge
CONFLICT_STATE="none"
[[ -f "$IN_MERGE" ]] && CONFLICT_STATE="merge"
[[ -d "$IN_REBASE" ]] && CONFLICT_STATE="rebase"

# Find conflicted files
CONFLICTED=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "")

if [[ -z "$CONFLICTED" ]]; then
	# No conflicts — show merge/rebase status
	if [[ "$CONFLICT_STATE" != "none" ]]; then
		jq -n --arg state "$CONFLICT_STATE" \
			'{"state":$state,"conflicts":0,"files":[],"msg":"in progress, no unresolved conflicts"}'
	else
		jq -n '{"state":"clean","conflicts":0,"files":[]}'
	fi
	exit 0
fi

# Count conflicts
CONFLICT_COUNT=$(echo "$CONFLICTED" | grep -c .) || CONFLICT_COUNT=0

# Extract conflict blocks from each file (compact: file + ours + theirs + context)
FILES_JSON="[]"
while IFS= read -r filepath; do
	[[ -z "$filepath" ]] && continue

	# Extract conflict blocks with perl (handles multi-line blocks)
	BLOCKS=$(perl -0777 -ne '
		my @blocks;
		while (/^<{7}\s*(.*?)\n(.*?)^={7}\n(.*?)^>{7}\s*(.*?)\n/msg) {
			my ($ours_label, $ours, $theirs, $theirs_label) = ($1, $2, $3, $4);
			$ours =~ s/\n/\\n/g;
			$theirs =~ s/\n/\\n/g;
			# Truncate long blocks
			$ours = substr($ours, 0, 300) . "..." if length($ours) > 300;
			$theirs = substr($theirs, 0, 300) . "..." if length($theirs) > 300;
			push @blocks, "{\"ours\":\"$ours\",\"theirs\":\"$theirs\"}";
		}
		print "[" . join(",", @blocks) . "]";
	' "$filepath" 2>/dev/null || echo "[]")

	BLOCK_COUNT=$(echo "$BLOCKS" | jq 'length' 2>/dev/null || echo 0)

	FILES_JSON=$(echo "$FILES_JSON" | jq \
		--arg file "$filepath" \
		--argjson blocks "$BLOCKS" \
		--argjson count "$BLOCK_COUNT" \
		'. + [{file: $file, blocks: $count, conflicts: $blocks}]')
done <<<"$CONFLICTED"

# Build result
jq -n \
	--arg state "$CONFLICT_STATE" \
	--argjson count "$CONFLICT_COUNT" \
	--argjson files "$FILES_JSON" \
	'{state:$state, conflicts:$count, files:$files}'
