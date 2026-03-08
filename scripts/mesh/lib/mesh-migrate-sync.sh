#!/usr/bin/env bash
# mesh-migrate-sync.sh — rsync helpers for mesh-migrate.sh
# Requires: lib/peers.sh sourced by caller | Bash 3.2 compatible
# v1.0.0

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
EXCLUDE_FILE="${CLAUDE_HOME}/config/mesh-rsync-exclude.txt"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# P: validate migration can proceed
# Args: plan_id target_peer
_migrate_preflight() {
	local plan_id="$1"
	local target_peer="$2"
	local db="${CLAUDE_HOME}/data/dashboard.db"

	# C-01: coordinator-only
	local my_role myhost
	myhost=$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
	my_role=$(sqlite3 "$db" ".timeout 5000" \
		"SELECT role FROM peer_heartbeats WHERE host='${myhost}' LIMIT 1;" 2>/dev/null || echo "")
	if [[ "$my_role" == "worker" ]]; then
		echo "ERROR: only coordinator can migrate plans (C-01)" >&2
		return 1
	fi

	# Reachability check
	local dest
	dest=$(peers_best_route "$target_peer" 2>/dev/null || echo "$target_peer")
	if ! ssh "$SSH_OPTS" "$dest" true 2>/dev/null; then
		echo "ERROR: target $target_peer unreachable" >&2
		return 1
	fi

	# Disk space on target (warn <5GB)
	local avail
	avail=$(ssh "$SSH_OPTS" "$dest" "df -k ~" 2>/dev/null |
		awk 'NR==2{print $4}' || echo "0")
	if [[ "$avail" -lt 5242880 ]]; then
		echo "WARN: target has <5GB free (${avail}KB)" >&2
	fi

	# Plan exists and is doing
	local plan_status
	plan_status=$(sqlite3 "$db" ".timeout 5000" \
		"SELECT status FROM plans WHERE id=${plan_id};" 2>/dev/null || echo "")
	if [[ "$plan_status" != "doing" ]]; then
		echo "ERROR: plan ${plan_id} status=${plan_status} (expected doing)" >&2
		return 1
	fi

	return 0
}

# Check tool versions source vs target
# Args: target_dest
_migrate_check_tools() {
	local dest="$1"
	local critical_missing=0

	printf "%-18s %-20s %-20s %s\n" "TOOL" "SOURCE" "TARGET" "MATCH"
	printf "%-18s %-20s %-20s %s\n" "----" "------" "------" "-----"

	for tool in "claude --version" "gh --version" "node --version" \
		"npm --version" "ollama --version" "tailscale version"; do
		local cmd name ver_src ver_tgt match
		name=$(echo "$tool" | awk '{print $1}')
		ver_src=$(eval "$tool" 2>/dev/null | awk 'NR==1' || echo "missing")
		ver_tgt=$(ssh "$SSH_OPTS" "$dest" "$tool" 2>/dev/null | awk 'NR==1' || echo "missing")

		if [[ "$ver_src" == "$ver_tgt" ]]; then
			match="YES"
		else
			match="NO"
		fi

		printf "%-18s %-20s %-20s %s\n" \
			"$name" "${ver_src:0:18}" "${ver_tgt:0:18}" "$match"

		if [[ "$ver_tgt" == "missing" ]] &&
			{ [[ "$name" == "claude" ]] || [[ "$name" == "gh" ]]; }; then
			critical_missing=1
		fi
	done

	return "$critical_missing"
}

# rsync a single path to target
# Args: target_dest source_path remote_path
_migrate_rsync() {
	local dest="$1"
	local src="$2"
	local remote="$3"

	rsync -avz --progress --delete \
		--exclude-from="$EXCLUDE_FILE" \
		-e "ssh $SSH_OPTS" \
		"$src" "${dest}:${remote}"
	return $?
}

# Sync all relevant paths to target
# Args: target_dest plan_id
_migrate_sync_all() {
	local dest="$1"
	local plan_id="$2"
	local db="${CLAUDE_HOME}/data/dashboard.db"
	local repos_conf="${CLAUDE_HOME}/config/repos.conf"
	local t0 elapsed files_sent

	t0=$(date +%s)

	echo "==> Syncing ~/.claude to ${dest}:~/.claude"
	# Exclude DB files — synced separately
	rsync -avz --progress --delete \
		--exclude-from="$EXCLUDE_FILE" \
		--exclude="data/*.db" --exclude="data/*.db-*" \
		-e "ssh $SSH_OPTS" \
		"${CLAUDE_HOME}/" "${dest}:${CLAUDE_HOME}/"

	# Repos from repos.conf
	if [[ -f "$repos_conf" ]]; then
		while IFS= read -r line; do
			[[ "$line" =~ ^\[.*\]$ ]] && section="${line//[\[\]]/}" && continue
			[[ "$line" =~ ^path=(.+)$ ]] || continue
			local repo_path="${BASH_REMATCH[1]/#\~/$HOME}"
			if [[ -d "$repo_path" ]]; then
				echo "==> Syncing repo ${section}: ${repo_path}"
				_migrate_rsync "$dest" "${repo_path}/" "${repo_path}/"
			fi
		done <"$repos_conf"
	fi

	# Wave worktrees from DB
	local worktrees
	worktrees=$(sqlite3 "$db" ".timeout 5000" \
		"SELECT worktree_path FROM waves WHERE plan_id=${plan_id} AND worktree_path <> '';" \
		2>/dev/null || echo "")
	while IFS= read -r wt; do
		[[ -z "$wt" ]] && continue
		local wt_path="${wt/#\~/$HOME}"
		if [[ -d "$wt_path" ]]; then
			echo "==> Syncing worktree: ${wt_path}"
			_migrate_rsync "$dest" "${wt_path}/" "${wt_path}/"
		fi
	done <<<"$worktrees"

	elapsed=$(($(date +%s) - t0))
	echo "Sync complete in ${elapsed}s"
}
