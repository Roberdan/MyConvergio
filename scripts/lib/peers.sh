#!/usr/bin/env bash
# peers.sh — Peer discovery library (sourced, not executed)
# NOTE: No set -euo pipefail — this is a sourced library, callers set their own error handling
# Version: 1.0.0
# Requires: bash 3.2+, ssh. Source this file, then call peers_load.
# Usage: source scripts/lib/peers.sh && peers_load && peers_list

# Guard: prevent direct execution
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
	echo "ERROR: peers.sh must be sourced." >&2
	exit 1
}

PEERS_CONF="${PEERS_CONF:-${CLAUDE_HOME:-$HOME/.claude}/config/peers.conf}"
_PEERS_ALL=""    # space-separated list of all peer names
_PEERS_ACTIVE="" # space-separated list of active peer names

# Internal: sanitize peer name for use in variable names
_peers_key_name() { echo "${1//[-.]/_}" | tr '[:lower:]' '[:upper:]'; }

# Internal: store peer field value
_peers_set() {
	local varname="_PEER_$(_peers_key_name "$1")_${2}"
	eval "${varname}=$(printf '%s' "$3" | sed "s/'/'\\''/g; s/^/'/; s/$/'/")"
}

# Internal: retrieve peer field value
_peers_get_raw() {
	local varname="_PEER_$(_peers_key_name "$1")_${2}"
	eval "printf '%s' \"\${${varname}:-}\""
}

# peers_load — parse peers.conf into internal state
peers_load() {
	_PEERS_ALL=""
	_PEERS_ACTIVE=""
	if [[ ! -f "$PEERS_CONF" ]]; then
		echo "ERROR: peers.conf not found: $PEERS_CONF" >&2
		return 1
	fi
	local current_peer="" line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		while [[ "$line" == [[:space:]]* ]]; do line="${line#?}"; done
		while [[ "$line" == *[[:space:]] ]]; do line="${line%?}"; done
		[[ -z "$line" ]] && continue
		if [[ "$line" == "["*"]" ]]; then
			current_peer="${line#[}"
			current_peer="${current_peer%]}"
			_PEERS_ALL="${_PEERS_ALL:+$_PEERS_ALL }$current_peer"
			_peers_set "$current_peer" "status" "active"
			continue
		fi
		if [[ -n "$current_peer" && "$line" == *"="* ]]; then
			key="${line%%=*}"
			val="${line#*=}"
			_peers_set "$current_peer" "$key" "$val"
		fi
	done <"$PEERS_CONF"
	local name st
	for name in $_PEERS_ALL; do
		st="$(_peers_get_raw "$name" "status")"
		[[ "$st" == "active" ]] && _PEERS_ACTIVE="${_PEERS_ACTIVE:+$_PEERS_ACTIVE }$name"
	done
}

# peers_list — echo active peer names, one per line
peers_list() {
	local name
	for name in $_PEERS_ACTIVE; do echo "$name"; done
}

# peers_get name field — return field value for named peer
peers_get() {
	local name="${1:-}" field="${2:-}" val
	if [[ -z "$name" || -z "$field" ]]; then
		echo "Usage: peers_get <name> <field>" >&2
		return 1
	fi
	val="$(_peers_get_raw "$name" "$field")"
	[[ -n "$val" ]] && echo "$val" || return 1
}

# peers_check name — SSH connectivity check; returns 0=reachable, 1=not
peers_check() {
	local name="${1:-}"
	[[ -z "$name" ]] && {
		echo "Usage: peers_check <name>" >&2
		return 1
	}
	local target user dest
	target="$(peers_best_route "$name")" || return 1
	[[ -z "$target" ]] && return 1
	user="$(_peers_get_raw "$name" "user")"
	dest="${user:+${user}@}${target}"
	ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
		-o BatchMode=yes -o LogLevel=quiet "$dest" true >/dev/null 2>&1
}

# peers_online — echo reachable active peer names
peers_online() {
	local name
	for name in $_PEERS_ACTIVE; do
		peers_check "$name" 2>/dev/null && echo "$name"
	done
}

# peers_with_capability cap — active peers with capability in their list
peers_with_capability() {
	local cap="${1:-}"
	[[ -z "$cap" ]] && {
		echo "Usage: peers_with_capability <capability>" >&2
		return 1
	}
	local name caps
	for name in $_PEERS_ACTIVE; do
		caps="$(_peers_get_raw "$name" "capabilities")"
		case ",$caps," in *",${cap},"*) echo "$name" ;; esac
	done
}

# peers_best_route name — try ssh_alias first, fallback tailscale_ip
peers_best_route() {
	local name="${1:-}"
	[[ -z "$name" ]] && {
		echo "Usage: peers_best_route <name>" >&2
		return 1
	}
	local alias ts_ip
	alias="$(_peers_get_raw "$name" "ssh_alias")"
	ts_ip="$(_peers_get_raw "$name" "tailscale_ip")"
	if [[ -n "$alias" ]]; then
		echo "$alias"
	elif [[ -n "$ts_ip" ]]; then
		echo "$ts_ip"
	else return 1; fi
}

# peers_self — detect current machine by matching hostname to peer entries
peers_self() {
	local current_host name alias
	current_host="$(hostname -s 2>/dev/null || hostname)"
	for name in $_PEERS_ALL; do
		alias="$(_peers_get_raw "$name" "ssh_alias")"
		if [[ "$alias" == "$current_host" || "$name" == "$current_host" ]]; then
			echo "$name"
			return 0
		fi
	done
	return 0
}

# peers_others — active peers excluding self
peers_others() {
	local self name
	self="$(peers_self)"
	for name in $_PEERS_ACTIVE; do
		[[ "$name" != "$self" ]] && echo "$name"
	done
}
