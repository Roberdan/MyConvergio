#!/usr/bin/env bash
set -euo pipefail

# agent-version-bump.sh — Bump semver version in component frontmatter
# Usage: agent-version-bump.sh <file-path> <major|minor|patch>

CLAUDE_DIR="${HOME}/.claude"
CHANGELOG="${CLAUDE_DIR}/CHANGELOG.md"

if [[ $# -lt 2 ]]; then
	echo "Usage: agent-version-bump.sh <file-path> <major|minor|patch>"
	exit 1
fi

FILE="$1"
BUMP="$2"

if [[ ! -f "$FILE" ]]; then
	echo "ERROR: File not found: $FILE"
	exit 1
fi

if [[ "$BUMP" != "major" && "$BUMP" != "minor" && "$BUMP" != "patch" ]]; then
	echo "ERROR: Bump type must be major, minor, or patch"
	exit 1
fi

# Extract current version
CURRENT=""
while IFS= read -r line; do
	if [[ "$line" =~ ^version:[[:space:]]*\"?([0-9]+\.[0-9]+\.[0-9]+)\"? ]]; then
		CURRENT="${BASH_REMATCH[1]}"
		break
	fi
done <"$FILE"

if [[ -z "$CURRENT" ]]; then
	echo "ERROR: No version field found in $FILE"
	exit 1
fi

# Parse semver
IFS='.' read -r major minor patch <<<"$CURRENT"

case "$BUMP" in
major)
	major=$((major + 1))
	minor=0
	patch=0
	;;
minor)
	minor=$((minor + 1))
	patch=0
	;;
patch) patch=$((patch + 1)) ;;
esac

NEW="${major}.${minor}.${patch}"

# Extract component name
NAME=""
while IFS= read -r line; do
	if [[ "$line" =~ ^name:[[:space:]]*(.+) ]]; then
		NAME="${BASH_REMATCH[1]}"
		break
	fi
done <"$FILE"

if [[ -z "$NAME" ]]; then
	NAME=$(basename "$FILE" .md)
fi

# Update version in file
if grep -q "version: \"${CURRENT}\"" "$FILE"; then
	sed -i '' "s/version: \"${CURRENT}\"/version: \"${NEW}\"/" "$FILE"
elif grep -q "version: ${CURRENT}" "$FILE"; then
	sed -i '' "s/version: ${CURRENT}/version: \"${NEW}\"/" "$FILE"
fi

# Verify update
UPDATED=$(grep -m1 'version:' "$FILE" || true)

# Append to CHANGELOG under [Unreleased]
if [[ -f "$CHANGELOG" ]]; then
	DATE=$(date +"%d %B %Y")
	ENTRY="- Bumped: ${NAME} ${CURRENT} -> ${NEW} (${BUMP})"
	# Insert after the first line that starts with "## [Unreleased]"
	if grep -q '## \[Unreleased\]' "$CHANGELOG"; then
		# Find the line number of [Unreleased] section, add entry after next blank line or ### block
		UNRELEASED_LINE=$(grep -n '## \[Unreleased\]' "$CHANGELOG" | head -1 | cut -d: -f1)
		# Find the next ### Changed or add one
		if grep -q '### Changed' "$CHANGELOG"; then
			CHANGED_LINE=$(awk "/## \[Unreleased\]/,/### Changed/" "$CHANGELOG" | grep -c '')
			CHANGED_LINE=$((UNRELEASED_LINE + CHANGED_LINE - 1))
			sed -i '' "${CHANGED_LINE}a\\
${ENTRY}" "$CHANGELOG"
		else
			sed -i '' "${UNRELEASED_LINE}a\\
\\
### Changed\\
${ENTRY}" "$CHANGELOG"
		fi
	fi
fi

echo "${NAME}: ${CURRENT} -> ${NEW}"
