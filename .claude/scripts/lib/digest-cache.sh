#!/bin/bash
# Digest Cache - Shared cache layer for service digest scripts
# Sourced by ci-digest.sh, pr-digest.sh, deploy-digest.sh
# Cache dir: /tmp/claude-digest-cache/
# TTL: configurable per caller

# Version: 1.2.0
DIGEST_CACHE_DIR="${TMPDIR:-/tmp}/claude-digest-cache"

# Verify jq is available (required by all digest scripts)
if ! command -v jq &>/dev/null; then
	echo '{"status":"error","msg":"jq not installed — required by digest scripts"}' >&2
	exit 1
fi

# Cross-platform short hash (macOS md5 vs Linux md5sum)
# Usage: digest_hash "string" → 8-char hex
digest_hash() {
	if command -v md5sum &>/dev/null; then
		echo -n "$1" | md5sum | cut -c1-8
	elif command -v md5 &>/dev/null; then
		echo -n "$1" | md5 | cut -c1-8
	else
		echo "x"
	fi
}

# Check cache freshness. Returns 0 (hit) or 1 (miss).
# Usage: digest_cache_get <key> <ttl_seconds>
# On hit, prints cached content to stdout.
digest_cache_get() {
	local key="$1" ttl="$2"
	local cache_file="$DIGEST_CACHE_DIR/$key"
	[[ ! -f "$cache_file" ]] && return 1
	local now age file_mod
	now=$(date +%s)
	# macOS stat vs Linux stat (default to 0 if both fail)
	file_mod=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
	age=$((now - ${file_mod:-0}))
	[[ $age -lt $ttl ]] && {
		cat "$cache_file"
		return 0
	}
	return 1
}

# Store result in cache.
# Usage: echo "$json" | digest_cache_set <key>
digest_cache_set() {
	local key="$1"
	mkdir -p "$DIGEST_CACHE_DIR"
	cat >"$DIGEST_CACHE_DIR/$key"
}

# Apply compact filter: keep only specified jq fields.
# Usage: echo "$json" | digest_compact_filter '.status, .exit_code, .errors'
# If COMPACT != 1, passes through unchanged.
digest_compact_filter() {
	local fields="$1"
	if [[ "${COMPACT:-0}" -eq 1 ]]; then
		jq "{${fields}}"
	else
		cat
	fi
}

# Parse --compact from args. Sets COMPACT=1 if found.
# Usage: digest_parse_args "$@" (call after sourcing, before arg parsing)
digest_check_compact() {
	for arg in "$@"; do
		[[ "$arg" == "--compact" ]] && {
			COMPACT=1
			return 0
		}
	done
	return 0
}

# Invalidate a specific cache key.
digest_cache_clear() {
	local key="$1"
	rm -f "$DIGEST_CACHE_DIR/$key" 2>/dev/null || true
}

# Invalidate all cache.
digest_cache_flush() {
	rm -rf "$DIGEST_CACHE_DIR" 2>/dev/null || true
}
