#!/usr/bin/env bash
# Version: 1.1.0
set -euo pipefail

# memory-save.sh - Create structured memory files for cross-session continuity
# Usage: memory-save.sh <project-name> "short description"

MEMORY_DIR="$HOME/.claude/memory"
ARCHIVE_DIR="$MEMORY_DIR/.archive"

usage() {
	echo "Usage: memory-save.sh <project-name> \"short description\""
	echo ""
	echo "Commands:"
	echo "  memory-save.sh <project> \"desc\"   Create new memory file"
	echo "  memory-save.sh list [project]      List memory files"
	echo "  memory-save.sh latest <project>    Show latest memory file path"
	echo "  memory-save.sh archive <days>      Archive files older than N days"
	exit 1
}

cmd="${1:-}"
[[ -z "$cmd" ]] && usage

case "$cmd" in
list)
	project="${2:-}"
	if [[ -n "$project" ]]; then
		target="$MEMORY_DIR/$project"
		[[ -d "$target" ]] || {
			echo "No memory files for $project"
			exit 0
		}
		ls -1t "$target"/*.md 2>/dev/null || echo "No memory files"
	else
		for dir in "$MEMORY_DIR"/*/; do
			[[ -d "$dir" ]] || continue
			name=$(basename "$dir")
			[[ "$name" == ".archive" ]] && continue
			count=$(find "$dir" -name "*.md" 2>/dev/null | /usr/bin/wc -l | tr -d ' ')
			latest=$(ls -1t "$dir"/*.md 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "none")
			echo "$name ($count files, latest: $latest)"
		done
	fi
	;;
latest)
	project="${2:?Missing project name}"
	target="$MEMORY_DIR/$project"
	[[ -d "$target" ]] || {
		echo "No memory files for $project"
		exit 1
	}
	ls -1t "$target"/*.md 2>/dev/null | head -1
	;;
archive)
	days="${2:-90}"
	mkdir -p "$ARCHIVE_DIR"
	found=0
	while IFS= read -r -d '' file; do
		rel=$(basename "$(dirname "$file")")/$(basename "$file")
		mkdir -p "$ARCHIVE_DIR/$(basename "$(dirname "$file")")"
		mv "$file" "$ARCHIVE_DIR/$rel"
		echo "Archived: $rel"
		((found++))
	done < <(find "$MEMORY_DIR" -name "*.md" -mtime +"$days" -not -path "*/.archive/*" -print0 2>/dev/null)
	echo "Archived $found files older than $days days"
	;;
*)
	# Default: create memory file
	project="$cmd"
	description="${2:?Missing description}"

	slug=$(echo "$description" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
	date_str=$(date +%Y-%m-%d)
	time_str=$(date +%H:%M)
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	target_dir="$MEMORY_DIR/$project"
	target_file="$target_dir/${date_str}-${slug}.md"

	mkdir -p "$target_dir"

	if [[ -f "$target_file" ]]; then
		echo "File already exists: $target_file"
		echo "Edit it directly or use a different description."
		exit 1
	fi

	cat >"$target_file" <<TEMPLATE
# Memory: ${description}
Project: ${project}
Date: ${timestamp}
Session: $(echo "${CLAUDE_SESSION_ID:-unknown}")

## Task Overview
- **Request**: [original user request]
- **Scope**: [in/out scope]
- **Status**: in_progress

## Completed Work
- [ ] [describe completed work]

## Modified Files
| File | Change | Status |
|------|--------|--------|
| path/to/file | description | committed/uncommitted |

## Decisions Made
| Decision | Rationale | Alternatives Rejected |
|----------|-----------|----------------------|
| [decision] | [why] | [what else was considered] |

## Failed Approaches
| Approach | Why It Failed | Lesson |
|----------|---------------|--------|
| [approach] | [reason] | [takeaway] |

## Next Steps (Priority Order)
1. [ ] [next action]

## Context to Preserve
- **Active branch**: $(git branch --show-current 2>/dev/null || echo "n/a")
- **Plan ID**: [if applicable]
- **Key files**: [files to read first]
- **Blockers**: [unresolved issues]
- **User preferences**: [preferences to remember]
TEMPLATE

	echo "Created: $target_file"
	;;
esac
