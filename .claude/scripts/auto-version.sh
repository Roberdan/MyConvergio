#!/usr/bin/env bash
set -euo pipefail
# auto-version.sh — Automatic semver bump based on conventional commits
# Usage: auto-version.sh [--dry-run] [--repo PATH]
# Reads commits since last tag, determines bump type, updates VERSION + CHANGELOG
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
REPO_PATH="${HOME}/GitHub/MyConvergio"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--repo)
		REPO_PATH="$2"
		shift 2
		;;
	*)
		echo "Usage: auto-version.sh [--dry-run] [--repo PATH]"
		exit 1
		;;
	esac
done

cd "$REPO_PATH" || {
	echo "ERROR: Repo not found: $REPO_PATH"
	exit 1
}

VERSION_FILE="${REPO_PATH}/VERSION"
CHANGELOG_FILE="${REPO_PATH}/CHANGELOG.md"

if [[ ! -f "$VERSION_FILE" ]]; then
	echo "ERROR: VERSION file not found at $VERSION_FILE"
	exit 1
fi

# Read current version
CURRENT_VERSION=$(awk -F= '/^SYSTEM_VERSION=/{print $2; exit}' "$VERSION_FILE")
if [[ -z "$CURRENT_VERSION" ]]; then
	echo "ERROR: SYSTEM_VERSION not found in VERSION file"
	exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT_VERSION"

# Get commits since last version tag or last 50 if no tags
LAST_TAG=$(git tag --sort=-v:refname 2>/dev/null | head -1)
if [[ -n "$LAST_TAG" ]]; then
	COMMITS=$(git log --oneline "${LAST_TAG}..HEAD" 2>/dev/null || echo "")
else
	COMMITS=$(git log --oneline -50 2>/dev/null || echo "")
fi

if [[ -z "$COMMITS" ]]; then
	echo "INFO: No new commits since last version ($CURRENT_VERSION). Nothing to do."
	exit 0
fi

# Determine bump type from conventional commits
HAS_BREAKING=false
HAS_FEAT=false
HAS_FIX=false

while IFS= read -r line; do
	msg="${line#* }" # Remove hash prefix
	if echo "$msg" | grep -qiE '^(feat|fix|chore|docs|refactor|perf|test|ci)(\(.*\))?!:'; then
		HAS_BREAKING=true
	elif echo "$msg" | grep -qiE '^feat(\(.*\))?:'; then
		HAS_FEAT=true
	elif echo "$msg" | grep -qiE '^fix(\(.*\))?:'; then
		HAS_FIX=true
	fi
done <<<"$COMMITS"

# Calculate new version
if $HAS_BREAKING; then
	MAJOR=$((MAJOR + 1))
	MINOR=0
	PATCH=0
	BUMP_TYPE="major"
elif $HAS_FEAT; then
	MINOR=$((MINOR + 1))
	PATCH=0
	BUMP_TYPE="minor"
elif $HAS_FIX; then
	PATCH=$((PATCH + 1))
	BUMP_TYPE="patch"
else
	echo "INFO: No conventional commits (feat/fix/breaking) found. Skipping bump."
	exit 0
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
TODAY=$(date +%Y-%m-%d)

echo "Version bump: ${CURRENT_VERSION} -> ${NEW_VERSION} (${BUMP_TYPE})"

if $DRY_RUN; then
	echo "[DRY RUN] Would update VERSION and CHANGELOG"
	echo "Commits:"
	echo "$COMMITS"
	exit 0
fi

# Update VERSION file
sed -i '' "s/^SYSTEM_VERSION=.*/SYSTEM_VERSION=${NEW_VERSION}/" "$VERSION_FILE"

# Generate CHANGELOG entry from commits
ADDED=""
CHANGED=""
FIXED=""

while IFS= read -r line; do
	msg="${line#* }"
	# Strip conventional commit prefix for clean entry
	clean_msg=$(echo "$msg" | sed -E 's/^(feat|fix|chore|docs|refactor|perf|test|ci)(\(.*\))?!?:[[:space:]]*//')
	if echo "$msg" | grep -qiE '^feat'; then
		ADDED="${ADDED}\n- ${clean_msg}"
	elif echo "$msg" | grep -qiE '^fix'; then
		FIXED="${FIXED}\n- ${clean_msg}"
	else
		CHANGED="${CHANGED}\n- ${clean_msg}"
	fi
done <<<"$COMMITS"

# Build changelog entry
ENTRY="## [${NEW_VERSION}] - ${TODAY}\n"
if [[ -n "$ADDED" ]]; then
	ENTRY="${ENTRY}\n### Added\n${ADDED}\n"
fi
if [[ -n "$CHANGED" ]]; then
	ENTRY="${ENTRY}\n### Changed\n${CHANGED}\n"
fi
if [[ -n "$FIXED" ]]; then
	ENTRY="${ENTRY}\n### Fixed\n${FIXED}\n"
fi
ENTRY="${ENTRY}\n---\n"

# Prepend to CHANGELOG (after header)
if [[ -f "$CHANGELOG_FILE" ]]; then
	# Insert after first line (# Changelog)
	HEADER=$(head -1 "$CHANGELOG_FILE")
	REST=$(tail -n +2 "$CHANGELOG_FILE")
	printf '%s\n\n%b\n%s' "$HEADER" "$ENTRY" "$REST" >"$CHANGELOG_FILE"
else
	printf '# Changelog\n\n%b' "$ENTRY" >"$CHANGELOG_FILE"
fi

echo "Updated: VERSION (${NEW_VERSION}), CHANGELOG.md"
echo "Run 'git add VERSION CHANGELOG.md && git commit -m \"chore: bump to v${NEW_VERSION}\"' to commit"
