#!/usr/bin/env bash
# remote-dispatch.sh — Execute a plan task on a remote peer via SSH.
# Usage: remote-dispatch.sh <task_db_id> <peer-name> [--engine claude|copilot|opencode|ollama] [--model M]
# Version: 1.0.0
# F-11: remote dispatch | F-12: cost attribution
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/peers.sh
source "${_SCRIPT_DIR}/lib/peers.sh"

DB_FILE="${PLAN_DB_FILE:-${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}}"

# ── Helpers ──────────────────────────────────────────────────────────────────
_die() {
	echo "ERROR: $*" >&2
	exit 1
}
_info() { echo "[remote-dispatch] $*"; }

usage() {
	cat >&2 <<'EOF'
Usage: remote-dispatch.sh <task_db_id> <peer-name> [OPTIONS]

Options:
  --engine  claude|copilot|opencode|ollama  (default: first capability on peer)
  --model   MODEL_NAME                      (passed through to worker)
  --help

Examples:
  remote-dispatch.sh 42 my-linux
  remote-dispatch.sh 42 my-linux --engine copilot
  remote-dispatch.sh 42 my-cloud --engine ollama --model llama3
EOF
	exit 1
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
TASK_DB_ID=""
PEER_NAME=""
ENGINE=""
MODEL=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--engine)
		ENGINE="$2"
		shift 2
		;;
	--model)
		MODEL="$2"
		shift 2
		;;
	--help | -h) usage ;;
	--*) _die "Unknown flag: $1" ;;
	*)
		if [[ -z "$TASK_DB_ID" ]]; then
			TASK_DB_ID="$1"
		elif [[ -z "$PEER_NAME" ]]; then
			PEER_NAME="$1"
		else
			_die "Unexpected argument: $1"
		fi
		shift
		;;
	esac
done

[[ -z "$TASK_DB_ID" || -z "$PEER_NAME" ]] && usage
[[ "$TASK_DB_ID" =~ ^[0-9]+$ ]] || _die "task_db_id must be numeric, got: $TASK_DB_ID"

# ── Load Peers ────────────────────────────────────────────────────────────────
peers_load || _die "Failed to load peers.conf"

# ── Step 1: Verify peer is online ─────────────────────────────────────────────
_info "Checking peer '$PEER_NAME'..."
if ! peers_check "$PEER_NAME" 2>/dev/null; then
	_die "Peer '$PEER_NAME' is offline or unreachable"
fi
_info "Peer '$PEER_NAME' is online."

# ── Step 2: Verify engine capability ─────────────────────────────────────────
PEER_CAPS="$(_peers_get_raw "$PEER_NAME" "capabilities")"
[[ -z "$PEER_CAPS" ]] && _die "Peer '$PEER_NAME' has no capabilities defined in peers.conf"

_peer_has_cap() {
	local cap="$1"
	case ",$PEER_CAPS," in *",${cap},"*) return 0 ;; esac
	return 1
}

# Select engine: use provided --engine or auto-detect first capability
if [[ -n "$ENGINE" ]]; then
	# Map ollama → opencode worker
	local_cap="$ENGINE"
	[[ "$ENGINE" == "ollama" ]] && local_cap="ollama"
	_peer_has_cap "$local_cap" || _die "Peer '$PEER_NAME' lacks capability '$local_cap' (has: $PEER_CAPS)"
else
	# Auto-detect: check default_engine first, then first recognized capability
	DEFAULT_ENG="$(_peers_get_raw "$PEER_NAME" "default_engine")"
	if [[ -n "$DEFAULT_ENG" ]] && _peer_has_cap "$DEFAULT_ENG"; then
		ENGINE="$DEFAULT_ENG"
		_info "Using peer default_engine: $ENGINE"
	else
		for cap in copilot claude opencode ollama; do
			if _peer_has_cap "$cap"; then
				ENGINE="$cap"
				break
			fi
		done
		[[ -z "$ENGINE" ]] && _die "No recognized engine in peer capabilities: $PEER_CAPS"
		_info "Auto-selected engine: $ENGINE"
	fi
fi

# ── Resolve SSH destination ───────────────────────────────────────────────────
PEER_HOST="$(peers_best_route "$PEER_NAME")" || _die "No route to peer '$PEER_NAME'"
PEER_USER="$(_peers_get_raw "$PEER_NAME" "user")"
SSH_DEST="${PEER_USER:+${PEER_USER}@}${PEER_HOST}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=10)

# ── Step 3: Record start in local DB ─────────────────────────────────────────
START_TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Fetch task meta for project/plan context
TASK_META="$(sqlite3 "$DB_FILE" \
	"SELECT project_id, plan_id FROM tasks WHERE id=$TASK_DB_ID LIMIT 1;" 2>/dev/null || true)"
PROJECT_ID="$(echo "$TASK_META" | cut -d'|' -f1)"
PLAN_ID="$(echo "$TASK_META" | cut -d'|' -f2)"

sqlite3 "$DB_FILE" \
	"INSERT INTO token_usage (project_id, plan_id, task_id, agent, model, input_tokens, output_tokens, cost_usd, created_at, execution_host)
	 VALUES ('$PROJECT_ID', ${PLAN_ID:-'NULL'}, '$TASK_DB_ID', 'remote-dispatch', '$ENGINE', 0, 0, 0.0, '$START_TS', '$PEER_NAME');" \
	2>/dev/null || true
LOCAL_ROW_ID="$(sqlite3 "$DB_FILE" "SELECT last_insert_rowid();" 2>/dev/null || echo "")"

# ── Step 4: Get worktree path from DB ────────────────────────────────────────
WORKTREE_PATH="$(sqlite3 "$DB_FILE" \
	"SELECT w.worktree_path FROM tasks t
	 JOIN waves w ON t.wave_id_fk = w.id
	 WHERE t.id = $TASK_DB_ID LIMIT 1;" 2>/dev/null || true)"
[[ -z "$WORKTREE_PATH" ]] && _info "Warning: no worktree_path in DB, using HOME on peer"

# ── Build remote worker command ───────────────────────────────────────────────
REMOTE_SCRIPTS="\$HOME/.claude/scripts"
MODEL_FLAG=""
[[ -n "$MODEL" ]] && MODEL_FLAG="--model $MODEL"

case "$ENGINE" in
claude)
	# Pre-resolve plan_id to avoid nested escaping issues in SSH
	_plan_id="$(sqlite3 "$DB_FILE" "SELECT plan_id FROM tasks WHERE id=$TASK_DB_ID;" 2>/dev/null)"
	REMOTE_CMD="cd ${WORKTREE_PATH:-\$HOME} && \
		export PATH=\"/opt/homebrew/bin:\$HOME/.local/bin:\$HOME/.claude/scripts:\$PATH\" && \
		claude --print -p 'Execute task $TASK_DB_ID from plan ${_plan_id}. Get details: plan-db.sh json ${_plan_id} $TASK_DB_ID' ${MODEL_FLAG:+--model ${MODEL}}"
	;;
copilot)
	REMOTE_CMD="cd ${WORKTREE_PATH:-\$HOME} && \
		export PATH=\"/opt/homebrew/bin:\$HOME/.local/bin:${REMOTE_SCRIPTS}:\$PATH\" && \
		${REMOTE_SCRIPTS}/copilot-worker.sh $TASK_DB_ID ${MODEL_FLAG}"
	;;
opencode)
	REMOTE_CMD="cd ${WORKTREE_PATH:-\$HOME} && \
		export PATH=\"${REMOTE_SCRIPTS}:\$PATH\" && \
		${REMOTE_SCRIPTS}/opencode-worker.sh $TASK_DB_ID ${MODEL_FLAG}"
	;;
ollama)
	OLLAMA_MODEL="${MODEL:-llama3}"
	REMOTE_CMD="cd ${WORKTREE_PATH:-\$HOME} && \
		export PATH=\"${REMOTE_SCRIPTS}:\$PATH\" && \
		${REMOTE_SCRIPTS}/opencode-worker.sh $TASK_DB_ID --model ollama/${OLLAMA_MODEL}"
	;;
*)
	_die "Unsupported engine: $ENGINE"
	;;
esac

# ── Step 5: Execute on peer, stream output ────────────────────────────────────
_info "Dispatching task $TASK_DB_ID to $PEER_NAME via $ENGINE..."
PEER_EXIT=0
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$SSH_DEST" "bash -lc '$REMOTE_CMD'" || PEER_EXIT=$?

# ── Step 6: Collect token_usage from peer, write merged row locally ───────────
if [[ $PEER_EXIT -eq 0 ]]; then
	_info "Collecting cost attribution from $PEER_NAME..."
	REMOTE_USAGE="$(ssh "${SSH_OPTS[@]}" "$SSH_DEST" \
		"sqlite3 \${PLAN_DB_FILE:-\$HOME/.claude/data/dashboard.db} \
		\"SELECT agent, model, SUM(input_tokens), SUM(output_tokens), SUM(cost_usd) \
		  FROM token_usage WHERE task_id='$TASK_DB_ID' GROUP BY agent, model;\"" \
		2>/dev/null || true)"

	if [[ -n "$REMOTE_USAGE" ]]; then
		END_TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
		while IFS='|' read -r r_agent r_model r_in r_out r_cost; do
			[[ -z "$r_agent" ]] && continue
			sqlite3 "$DB_FILE" \
				"INSERT INTO token_usage (project_id, plan_id, task_id, agent, model, input_tokens, output_tokens, cost_usd, created_at, execution_host)
				 VALUES ('$PROJECT_ID', ${PLAN_ID:-'NULL'}, '$TASK_DB_ID', '$r_agent', '$r_model', ${r_in:-0}, ${r_out:-0}, ${r_cost:-0}, '$END_TS', '$PEER_NAME');" \
				2>/dev/null || true
		done <<<"$REMOTE_USAGE"

		# Remove the placeholder start row
		[[ -n "$LOCAL_ROW_ID" ]] &&
			sqlite3 "$DB_FILE" "DELETE FROM token_usage WHERE id=$LOCAL_ROW_ID;" 2>/dev/null || true

		_info "Cost attribution recorded from $PEER_NAME"
	fi
fi

# ── Step 7: Return peer exit code ─────────────────────────────────────────────
[[ $PEER_EXIT -ne 0 ]] && _info "Peer exited with code $PEER_EXIT"
exit $PEER_EXIT
