#!/usr/bin/env bash
set -euo pipefail
# auto-version-bump.sh — Automatic semver bump from conventional commits
# Usage: auto-version-bump.sh [--dry-run] [--repo PATH] [--no-tag] [--no-changelog]
# Source of truth: git tags (vX.Y.Z). No VERSION file needed.
# Version: 1.0.0

DRY_RUN=false
REPO_PATH=""
CREATE_TAG=true
UPDATE_CHANGELOG=true

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
	--no-tag)
		CREATE_TAG=false
		shift
		;;
	--no-changelog)
		UPDATE_CHANGELOG=false
		shift
		;;
	-h | --help)
		echo "Usage: auto-version-bump.sh [--dry-run] [--repo PATH] [--no-tag] [--no-changelog]"
		echo "Reads commits since last vX.Y.Z tag, bumps semver, updates CHANGELOG, creates tag."
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
	esac
done

[[ -n "$REPO_PATH" ]] && cd "$REPO_PATH"

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || {
	echo "ERROR: not a git repo"
	exit 1
}

# Find latest semver tag
LAST_TAG=$(git tag --sort=-v:refname 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")
if [[ -z "$LAST_TAG" ]]; then
	echo "INFO: No semver tag found. Creating v0.1.0"
	CURRENT="0.0.0"
	COMMITS=$(git log --oneline -50 2>/dev/null || echo "")
else
	CURRENT="${LAST_TAG#v}"
	COMMITS=$(git log --oneline "${LAST_TAG}..HEAD" 2>/dev/null || echo "")
fi

if [[ -z "$COMMITS" ]]; then
	echo "INFO: No new commits since ${LAST_TAG:-start}. Nothing to bump."
	exit 0
fi

IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT"

# Determine bump type from conventional commits
HAS_BREAKING=false
HAS_FEAT=false
HAS_FIX=false

while IFS= read -r line; do
	[[ -z "$line" ]] && continue
	msg="${line#* }"
	if echo "$msg" | grep -qiE '^(feat|fix|chore|docs|refactor|perf|test|ci)(\(.*\))?!:'; then
		HAS_BREAKING=true
	elif echo "$msg" | grep -qiE 'BREAKING CHANGE'; then
		HAS_BREAKING=true
	elif echo "$msg" | grep -qiE '^feat(\(.*\))?:'; then
		HAS_FEAT=true
	elif echo "$msg" | grep -qiE '^fix(\(.*\))?:'; then
		HAS_FIX=true
	fi
done <<<"$COMMITS"

if $HAS_BREAKING; then
	MAJOR=$((MAJOR + 1))
	MINOR=0
	PATCH=0
	BUMP="major"
elif $HAS_FEAT; then
	MINOR=$((MINOR + 1))
	PATCH=0
	BUMP="minor"
elif $HAS_FIX; then
	PATCH=$((PATCH + 1))
	BUMP="patch"
else
	# Non-conventional commits → patch bump (every push must version)
	PATCH=$((PATCH + 1))
	BUMP="patch"
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"
TODAY=$(date +"%d %b %Y")

echo "Version: ${LAST_TAG:-v0.0.0} → ${NEW_TAG} (${BUMP})"

if $DRY_RUN; then
	echo "[DRY RUN] Would create tag ${NEW_TAG} and update CHANGELOG"
	echo "Commits since ${LAST_TAG:-start}:"
	echo "$COMMITS"
	exit 0
fi

# Update CHANGELOG.md
if $UPDATE_CHANGELOG; then
	CHANGELOG="CHANGELOG.md"
	ADDED="" CHANGED="" FIXED=""

	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		msg="${line#* }"
		clean=$(echo "$msg" | sed -E 's/^(feat|fix|chore|docs|refactor|perf|test|ci|release|build)(\(.*\))?!?:[[:space:]]*//')
		if echo "$msg" | grep -qiE '^feat'; then
			ADDED="${ADDED}- ${clean}"$'\n'
		elif echo "$msg" | grep -qiE '^fix'; then
			FIXED="${FIXED}- ${clean}"$'\n'
		else
			CHANGED="${CHANGED}- ${clean}"$'\n'
		fi
	done <<<"$COMMITS"

	ENTRY="## [${NEW_TAG}] - ${TODAY}"$'\n'
	[[ -n "$ADDED" ]] && ENTRY="${ENTRY}"$'\n'"### Added"$'\n'"${ADDED}"
	[[ -n "$FIXED" ]] && ENTRY="${ENTRY}"$'\n'"### Fixed"$'\n'"${FIXED}"
	[[ -n "$CHANGED" ]] && ENTRY="${ENTRY}"$'\n'"### Changed"$'\n'"${CHANGED}"

	if [[ -f "$CHANGELOG" ]]; then
		HEADER=$(head -1 "$CHANGELOG")
		REST=$(tail -n +2 "$CHANGELOG")
		printf '%s\n\n%s\n%s' "$HEADER" "$ENTRY" "$REST" >"$CHANGELOG"
	else
		printf '# Changelog\n\n%s\n' "$ENTRY" >"$CHANGELOG"
	fi
	echo "Updated CHANGELOG.md"
fi

# Create git tag
if $CREATE_TAG; then
	# Stage changelog if updated
	$UPDATE_CHANGELOG && git add CHANGELOG.md 2>/dev/null || true
	# Amend the last commit to include changelog (if there are staged changes)
	if git diff --cached --quiet 2>/dev/null; then
		: # No staged changes, just tag
	else
		git commit --amend --no-edit --no-verify 2>/dev/null || true
	fi
	git tag "$NEW_TAG" 2>/dev/null || { echo "WARN: tag ${NEW_TAG} already exists"; }
	echo "Created tag ${NEW_TAG}"
fi

echo "Done: ${NEW_TAG}"
