#!/usr/bin/env bash
# sync-dashboard-db-multi.sh — Multi-peer DB sync operations (push-all, pull-all, status-all)
# Sourced by sync-dashboard-db.sh. Requires: peers.sh, common.sh already sourced.
# Version: 1.0.0
# F-08, F-27, C-02, C-05

# Guard: must be sourced
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
	echo "ERROR: sync-dashboard-db-multi.sh must be sourced." >&2
	exit 1
}

# _multi_peer_db peer_name — return remote DB path for a peer
_multi_peer_db() {
	local peer="$1"
	local db
	db="$(peers_get "$peer" "db_path" 2>/dev/null)" || db="${REMOTE_DB:-~/.claude/data/dashboard.db}"
	echo "$db"
}

# _multi_peer_host peer_name — return SSH destination (user@host or alias)
_multi_peer_host() {
	local peer="$1"
	local route user dest
	route="$(peers_best_route "$peer" 2>/dev/null)" || return 1
	user="$(peers_get "$peer" "user" 2>/dev/null)" || user=""
	dest="${user:+${user}@}${route}"
	echo "$dest"
}

# _multi_peer_online peer_name — 0=reachable, 1=offline; logs warning if offline
_multi_peer_online() {
	local peer="$1"
	if peers_check "$peer" >/dev/null 2>&1; then
		return 0
	fi
	log_warn "Peer '$peer' is offline — skipping"
	return 1
}

# _multi_push_peer peer_name — push LOCAL_DB to a single peer (latest-wins by updated_at)
_multi_push_peer() {
	local peer="$1"
	local dest peer_db tmp_src
	dest="$(_multi_peer_host "$peer")" || {
		log_warn "Peer '$peer': no route"
		return 1
	}
	peer_db="$(_multi_peer_db "$peer")"
	tmp_src="${TMPDIR:-/tmp}/sync_push_$peer.db"

	log_info "push-all → $peer ($dest)"
	scp -q "$LOCAL_DB" "${dest}:${tmp_src}" 2>/dev/null || {
		log_warn "Peer '$peer': scp failed"
		return 1
	}

	ssh -o ConnectTimeout=10 "$dest" bash -s -- "$peer_db" "$tmp_src" <<'PUSH_PEER'
PEER_DB="$1"; SRC="$2"
sqlite3 "$PEER_DB" "
	ATTACH '$SRC' AS src;
	INSERT INTO plans SELECT * FROM src.plans WHERE true
		ON CONFLICT(id) DO UPDATE SET
			name=excluded.name, status=excluded.status,
			tasks_done=excluded.tasks_done, tasks_total=excluded.tasks_total,
			updated_at=excluded.updated_at, completed_at=excluded.completed_at,
			execution_host=excluded.execution_host, human_summary=excluded.human_summary,
			worktree_path=excluded.worktree_path, source_file=excluded.source_file,
			pr_number=excluded.pr_number, pr_url=excluded.pr_url
		WHERE excluded.updated_at >= COALESCE(plans.updated_at, '1970-01-01');
	INSERT INTO waves SELECT * FROM src.waves WHERE true
		ON CONFLICT(id) DO UPDATE SET
			status=excluded.status, tasks_done=excluded.tasks_done, tasks_total=excluded.tasks_total,
			updated_at=excluded.updated_at, branch_name=excluded.branch_name,
			worktree_path=excluded.worktree_path, pr_number=excluded.pr_number, pr_url=excluded.pr_url
		WHERE excluded.updated_at >= COALESCE(waves.updated_at, '1970-01-01');
	INSERT INTO tasks SELECT * FROM src.tasks WHERE true
		ON CONFLICT(id) DO UPDATE SET
			status=excluded.status, title=excluded.title, updated_at=excluded.updated_at,
			completed_at=excluded.completed_at, validated_by=excluded.validated_by,
			tokens=excluded.tokens, notes=excluded.notes
		WHERE excluded.updated_at >= COALESCE(tasks.updated_at, '1970-01-01');
	INSERT OR IGNORE INTO token_usage SELECT * FROM src.token_usage;
	DETACH src;
" 2>&1
rm -f "$SRC"
PUSH_PEER
	local rc=$?
	[[ $rc -eq 0 ]] && log_info "push-all → $peer: OK" || log_warn "Peer '$peer': push partial (rc=$rc)"
}

# _multi_pull_peer peer_name — pull from a single peer into LOCAL_DB (latest-wins)
_multi_pull_peer() {
	local peer="$1"
	local dest peer_db tmp_dst
	dest="$(_multi_peer_host "$peer")" || {
		log_warn "Peer '$peer': no route"
		return 1
	}
	peer_db="$(_multi_peer_db "$peer")"
	tmp_dst="${TMPDIR:-/tmp}/sync_pull_$peer.db"

	log_info "pull-all ← $peer ($dest)"
	scp -q "${dest}:${peer_db}" "$tmp_dst" 2>/dev/null || {
		log_warn "Peer '$peer': scp failed"
		return 1
	}

	sqlite3 "$LOCAL_DB" "
		ATTACH '$tmp_dst' AS src;
		INSERT INTO plans SELECT * FROM src.plans
			WHERE true
			ON CONFLICT(id) DO UPDATE SET
				name=excluded.name, status=excluded.status,
				tasks_done=excluded.tasks_done, tasks_total=excluded.tasks_total,
				updated_at=excluded.updated_at, completed_at=excluded.completed_at,
				execution_host=excluded.execution_host, human_summary=excluded.human_summary,
				worktree_path=excluded.worktree_path, source_file=excluded.source_file,
				pr_number=excluded.pr_number, pr_url=excluded.pr_url
			WHERE excluded.updated_at >= COALESCE(plans.updated_at, '1970-01-01');
		INSERT INTO waves SELECT * FROM src.waves
			WHERE true
			ON CONFLICT(id) DO UPDATE SET
				status=excluded.status, tasks_done=excluded.tasks_done, tasks_total=excluded.tasks_total,
				updated_at=excluded.updated_at, branch_name=excluded.branch_name,
				worktree_path=excluded.worktree_path, pr_number=excluded.pr_number, pr_url=excluded.pr_url
			WHERE excluded.updated_at >= COALESCE(waves.updated_at, '1970-01-01');
		INSERT INTO tasks SELECT * FROM src.tasks
			WHERE true
			ON CONFLICT(id) DO UPDATE SET
				status=excluded.status, title=excluded.title, updated_at=excluded.updated_at,
				completed_at=excluded.completed_at, validated_by=excluded.validated_by,
				tokens=excluded.tokens, notes=excluded.notes
			WHERE excluded.updated_at >= COALESCE(tasks.updated_at, '1970-01-01');
		INSERT OR IGNORE INTO token_usage SELECT * FROM src.token_usage;
		DETACH src;
	" 2>/dev/null
	local rc=$?
	rm -f "$tmp_dst"
	[[ $rc -eq 0 ]] && log_info "pull-all ← $peer: OK" || log_warn "Peer '$peer': pull partial (rc=$rc)"
}

# multi_push_all — push LOCAL_DB to all active peers (offline peers skipped)
multi_push_all() {
	peers_load || {
		log_error "Cannot load peers.conf"
		return 1
	}
	local peers
	peers="$(peers_others)"
	if [[ -z "$peers" ]]; then
		log_warn "No other active peers found in peers.conf"
		return 0
	fi
	local peer failed=0
	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		_multi_peer_online "$peer" || {
			((failed++))
			continue
		}
		_multi_push_peer "$peer" || ((failed++))
	done <<<"$peers"
	[[ $failed -gt 0 ]] && log_warn "push-all: $failed peer(s) had errors"
	return 0
}

# multi_pull_all — pull from all active peers, merge latest-wins into LOCAL_DB
multi_pull_all() {
	peers_load || {
		log_error "Cannot load peers.conf"
		return 1
	}
	local peers
	peers="$(peers_others)"
	if [[ -z "$peers" ]]; then
		log_warn "No other active peers found in peers.conf"
		return 0
	fi
	backup_local
	local peer failed=0
	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		_multi_peer_online "$peer" || {
			((failed++))
			continue
		}
		_multi_pull_peer "$peer" || ((failed++))
	done <<<"$peers"
	[[ $failed -gt 0 ]] && log_warn "pull-all: $failed peer(s) had errors"
	return 0
}

# multi_status_all — table of DB state per peer (last sync, row counts)
multi_status_all() {
	peers_load || {
		log_error "Cannot load peers.conf"
		return 1
	}

	local local_plans local_tasks local_waves local_tokens
	local_plans=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM plans;" 2>/dev/null || echo "?")
	local_tasks=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "?")
	local_waves=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM waves;" 2>/dev/null || echo "?")
	local_tokens=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM token_usage;" 2>/dev/null || echo "?")
	local self
	self="$(peers_self)"

	printf "%-18s %-10s %-8s %-8s %-8s %-8s %s\n" "PEER" "STATUS" "PLANS" "TASKS" "WAVES" "TOKENS" "LAST_SEEN"
	printf "%-18s %-10s %-8s %-8s %-8s %-8s %s\n" "$(printf '%0.s-' {1..18})" "----------" "--------" "--------" "--------" "--------" "---------"
	printf "%-18s %-10s %-8s %-8s %-8s %-8s %s\n" "${self:-local}(self)" "local" "$local_plans" "$local_tasks" "$local_waves" "$local_tokens" "$(date '+%Y-%m-%d %H:%M')"

	local peers
	peers="$(peers_others)"
	[[ -z "$peers" ]] && {
		log_warn "No other active peers."
		return 0
	}

	local peer dest peer_db
	while IFS= read -r peer; do
		[[ -z "$peer" ]] && continue
		if ! _multi_peer_online "$peer" 2>/dev/null; then
			printf "%-18s %-10s %-8s %-8s %-8s %-8s %s\n" "$peer" "OFFLINE" "-" "-" "-" "-" "-"
			continue
		fi
		dest="$(_multi_peer_host "$peer")"
		peer_db="$(_multi_peer_db "$peer")"
		local stats
		stats=$(ssh -o ConnectTimeout=8 "$dest" \
			"sqlite3 '$peer_db' \"SELECT COUNT(*) FROM plans;\" 2>/dev/null; \
			 sqlite3 '$peer_db' \"SELECT COUNT(*) FROM tasks;\" 2>/dev/null; \
			 sqlite3 '$peer_db' \"SELECT COUNT(*) FROM waves;\" 2>/dev/null; \
			 sqlite3 '$peer_db' \"SELECT COUNT(*) FROM token_usage;\" 2>/dev/null; \
			 cat ~/.claude/data/last-sync.txt 2>/dev/null || echo '-'" 2>/dev/null) || stats=""
		local p_plans p_tasks p_waves p_tokens p_sync
		p_plans=$(echo "$stats" | sed -n '1p')
		p_tasks=$(echo "$stats" | sed -n '2p')
		p_waves=$(echo "$stats" | sed -n '3p')
		p_tokens=$(echo "$stats" | sed -n '4p')
		p_sync=$(echo "$stats" | sed -n '5p')
		printf "%-18s %-10s %-8s %-8s %-8s %-8s %s\n" \
			"$peer" "online" "${p_plans:--}" "${p_tasks:--}" "${p_waves:--}" "${p_tokens:--}" "${p_sync:--}"
	done <<<"$peers"
}
