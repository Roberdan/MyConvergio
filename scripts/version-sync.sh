#!/usr/bin/env bash
# version-sync.sh — Propagate SYSTEM_VERSION from VERSION to all consumers
# Version: 1.0.0
# Zero external deps (bash + sed + grep)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$ROOT_DIR/VERSION"

# Read system version from source of truth
SYSTEM_VERSION=$(grep '^SYSTEM_VERSION=' "$VERSION_FILE" | cut -d= -f2)
if [[ -z "$SYSTEM_VERSION" ]]; then
	echo "ERROR: SYSTEM_VERSION not found in $VERSION_FILE" >&2
	exit 1
fi

update_file() {
	local file="$1" pattern="$2" replacement="$3"
	if [[ ! -f "$file" ]]; then
		echo "SKIP (not found): $file"
		return
	fi
	sed -i "s|$pattern|$replacement|g" "$file"
}

# README.md: **v9.x.x** occurrences in badge and footer lines
update_file "$ROOT_DIR/README.md" \
	'\*\*v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\*\*' \
	"**v${SYSTEM_VERSION}**"

# AGENTS.md: **v9.x.x** badge line and "**Current**: v9.x.x"
update_file "$ROOT_DIR/AGENTS.md" \
	'\*\*v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\*\*' \
	"**v${SYSTEM_VERSION}**"
update_file "$ROOT_DIR/AGENTS.md" \
	'\*\*Current\*\*: v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' \
	"**Current**: v${SYSTEM_VERSION}"

# scripts/myconvergio.sh: header comment version
update_file "$ROOT_DIR/scripts/myconvergio.sh" \
	'MyConvergio CLI v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' \
	"MyConvergio CLI v${SYSTEM_VERSION}"

# Makefile: help echo version string
update_file "$ROOT_DIR/Makefile" \
	'MyConvergio Agent Management v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' \
	"MyConvergio Agent Management v${SYSTEM_VERSION}"

# plugin.json: "version" field
update_file "$ROOT_DIR/plugin.json" \
	'"version": "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"' \
	"\"version\": \"${SYSTEM_VERSION}\""

echo "version-sync: propagated v${SYSTEM_VERSION} to all consumers"
