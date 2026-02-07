#!/bin/bash
# Digest Cache - Shared cache layer for service digest scripts
# Sourced by ci-digest.sh, pr-digest.sh, deploy-digest.sh
# Cache dir: /tmp/claude-digest-cache/
# TTL: configurable per caller

DIGEST_CACHE_DIR="/tmp/claude-digest-cache"

# Check cache freshness. Returns 0 (hit) or 1 (miss).
# Usage: digest_cache_get <key> <ttl_seconds>
# On hit, prints cached content to stdout.
digest_cache_get() {
	local key="$1" ttl="$2"
	local cache_file="$DIGEST_CACHE_DIR/$key"
	[[ ! -f "$cache_file" ]] && return 1
	local now age file_mod
	now=$(date +%s)
	# macOS stat vs Linux stat
	file_mod=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
	age=$((now - file_mod))
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

# Invalidate a specific cache key.
digest_cache_clear() {
	local key="$1"
	rm -f "$DIGEST_CACHE_DIR/$key" 2>/dev/null || true
}

# Invalidate all cache.
digest_cache_flush() {
	rm -rf "$DIGEST_CACHE_DIR" 2>/dev/null || true
}
