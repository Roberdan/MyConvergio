#!/usr/bin/env bash
set -euo pipefail
# batch-dispatcher.sh v1.0.0
# Submit a plan task to Anthropic Batch API, poll for result, update DB.
# Usage: batch-dispatcher.sh --task-id ID --plan-id ID --prompt "text"
#        batch-dispatcher.sh <task_id> <plan_id> <prompt>
# Eligibility: effort_level=1 AND type IN (chore, doc, documentation, test)
# Requires: ANTHROPIC_API_KEY env var

DB_FILE="${CLAUDE_DB:-$HOME/.claude/data/dashboard.db}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_ELIGIBLE=false

# ── Argument Parsing ──────────────────────────────────────────────────────────
TASK_ID=""
PLAN_ID=""
PROMPT=""
MODEL="${BATCH_MODEL:-claude-haiku-4-5}"
MAX_TOKENS="${BATCH_MAX_TOKENS:-2048}"

usage() {
	echo "Usage: batch-dispatcher.sh --task-id ID --plan-id ID --prompt TEXT [--model M]" >&2
	echo "Env: ANTHROPIC_API_KEY (required), BATCH_MODEL, BATCH_MAX_TOKENS" >&2
	exit 1
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--task-id)
		TASK_ID="$2"
		shift 2
		;;
	--plan-id)
		PLAN_ID="$2"
		shift 2
		;;
	--prompt)
		PROMPT="$2"
		shift 2
		;;
	--model)
		MODEL="$2"
		shift 2
		;;
	--help | -h) usage ;;
	--*)
		echo "Unknown flag: $1" >&2
		usage
		;;
	*)
		POSITIONAL+=("$1")
		shift
		;;
	esac
done

# Positional fallback
if [[ -z "$TASK_ID" && ${#POSITIONAL[@]} -ge 1 ]]; then TASK_ID="${POSITIONAL[0]}"; fi
if [[ -z "$PLAN_ID" && ${#POSITIONAL[@]} -ge 2 ]]; then PLAN_ID="${POSITIONAL[1]}"; fi
if [[ -z "$PROMPT" && ${#POSITIONAL[@]} -ge 3 ]]; then PROMPT="${POSITIONAL[2]}"; fi

if [[ -z "$TASK_ID" || -z "$PLAN_ID" || -z "$PROMPT" ]]; then
	echo '{"error":"missing_args","required":["task_id","plan_id","prompt"]}' >&2
	usage
fi

# ── Eligibility Check ─────────────────────────────────────────────────────────
check_eligibility() {
	local row
	row="$(sqlite3 "$DB_FILE" \
		"SELECT effort_level, type FROM tasks WHERE id=$TASK_ID AND plan_id=$PLAN_ID LIMIT 1;" 2>/dev/null || true)"

	if [[ -z "$row" ]]; then
		echo '{"error":"task_not_found","task_id":'"$TASK_ID"',"plan_id":'"$PLAN_ID"'}' >&2
		exit 1
	fi

	local effort type
	effort="$(echo "$row" | cut -d'|' -f1)"
	type="$(echo "$row" | cut -d'|' -f2)"

	if [[ "$effort" != "1" ]]; then
		echo '{"error":"not_eligible","reason":"effort_level_not_1","effort_level":'"$effort"',"task_id":'"$TASK_ID"'}' >&2
		exit 1
	fi

	case "$type" in
	chore | doc | documentation | test) BATCH_ELIGIBLE=true ;;
	*)
		echo '{"error":"not_eligible","reason":"type_not_allowed","type":"'"$type"'","task_id":'"$TASK_ID"'}' >&2
		exit 1
		;;
	esac
}

# ── Batch Submit ──────────────────────────────────────────────────────────────
submit_batch() {
	if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
		echo '{"error":"missing_env","var":"ANTHROPIC_API_KEY"}' >&2
		exit 1
	fi

	local custom_id="task-${TASK_ID}-plan-${PLAN_ID}"
	local escaped_prompt
	escaped_prompt="$(printf '%s' "$PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
	local payload
	payload="{\"requests\":[{\"custom_id\":\"$custom_id\",\"params\":{\"model\":\"$MODEL\",\"max_tokens\":$MAX_TOKENS,\"messages\":[{\"role\":\"user\",\"content\":$escaped_prompt}]}}]}"

	curl -s -X POST \
		"https://api.anthropic.com/v1/messages/batches" \
		-H "x-api-key: $ANTHROPIC_API_KEY" \
		-H "anthropic-version: 2023-06-01" \
		-H "anthropic-beta: message-batches-2024-09-24" \
		-H "content-type: application/json" \
		-d "$payload"
}

# ── Poll Until Done ───────────────────────────────────────────────────────────
poll_batch() {
	local batch_id="$1"
	local delays=(5 15 30 60)
	local attempt=0
	local max_attempts=20

	while [[ $attempt -lt $max_attempts ]]; do
		local response
		response="$(curl -s \
			"https://api.anthropic.com/v1/messages/batches/${batch_id}" \
			-H "x-api-key: $ANTHROPIC_API_KEY" \
			-H "anthropic-version: 2023-06-01" \
			-H "anthropic-beta: message-batches-2024-09-24")"

		local processing_status
		processing_status="$(echo "$response" | python3 -c \
			'import sys,json; d=json.load(sys.stdin); print(d.get("processing_status",""))' 2>/dev/null || echo "")"

		if [[ "$processing_status" != "in_progress" ]]; then
			echo "$response"
			return 0
		fi

		local delay_idx=$((attempt < ${#delays[@]} ? attempt : ${#delays[@]} - 1))
		sleep "${delays[$delay_idx]}"
		((attempt++))
	done

	echo '{"error":"poll_timeout","batch_id":"'"$batch_id"'"}' >&2
	return 1
}

# ── Parse Result + Log Tokens ─────────────────────────────────────────────────
parse_and_log() {
	local batch_id="$1"
	local result_response="$2"

	local input_tokens=0
	local output_tokens=0

	local results_url
	results_url="$(echo "$result_response" | python3 -c \
		'import sys,json; d=json.load(sys.stdin); print(d.get("results_url",""))' 2>/dev/null || echo "")"

	if [[ -n "$results_url" ]]; then
		local results
		results="$(curl -s "$results_url" \
			-H "x-api-key: $ANTHROPIC_API_KEY" \
			-H "anthropic-version: 2023-06-01" \
			-H "anthropic-beta: message-batches-2024-09-24" || echo "")"

		if [[ -n "$results" ]]; then
			input_tokens="$(echo "$results" | python3 -c $'import sys, json\ntotal = 0\nfor line in sys.stdin:\n    line = line.strip()\n    if not line: continue\n    try:\n        d = json.loads(line)\n        total += d.get(\"result\", {}).get(\"message\", {}).get(\"usage\", {}).get(\"input_tokens\", 0)\n    except (json.JSONDecodeError, ValueError): pass\nprint(total)' 2>/dev/null || echo "0")"
			output_tokens="$(echo "$results" | python3 -c $'import sys, json\ntotal = 0\nfor line in sys.stdin:\n    line = line.strip()\n    if not line: continue\n    try:\n        d = json.loads(line)\n        total += d.get(\"result\", {}).get(\"message\", {}).get(\"usage\", {}).get(\"output_tokens\", 0)\n    except (json.JSONDecodeError, ValueError): pass\nprint(total)' 2>/dev/null || echo "0")"
		fi
	fi

	local ts
	ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	sqlite3 "$DB_FILE" \
		"INSERT OR IGNORE INTO token_usage (plan_id, task_id, agent, model, input_tokens, output_tokens, created_at) \
		 VALUES ($PLAN_ID, '$TASK_ID', 'batch-api', '$MODEL', $input_tokens, $output_tokens, '$ts');" 2>/dev/null || true

	echo "$input_tokens $output_tokens"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
	check_eligibility

	if [[ "$BATCH_ELIGIBLE" != "true" ]]; then
		echo '{"error":"not_eligible","task_id":'"$TASK_ID"'}' >&2
		exit 1
	fi

	echo "[batch-dispatcher] Submitting task $TASK_ID to Batch API..." >&2

	local submit_response batch_id
	submit_response="$(submit_batch)"
	batch_id="$(echo "$submit_response" | python3 -c \
		'import sys,json; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || echo "")"

	if [[ -z "$batch_id" ]]; then
		echo "[batch-dispatcher] Submit failed: $submit_response" >&2
		"$SCRIPTS_DIR/plan-db.sh" update-task "$TASK_ID" blocked "Batch submit failed" 2>/dev/null || true
		exit 1
	fi

	echo "[batch-dispatcher] Batch ID: $batch_id — polling..." >&2

	local poll_result
	if poll_result="$(poll_batch "$batch_id")"; then
		local status
		status="$(echo "$poll_result" | python3 -c \
			'import sys,json; d=json.load(sys.stdin); rc=d.get("request_counts",{}); print("succeeded" if rc.get("succeeded",0)>0 else "errored")' \
			2>/dev/null || echo "errored")"

		local tokens in_tok out_tok total_tok
		tokens="$(parse_and_log "$batch_id" "$poll_result")"
		in_tok="$(echo "$tokens" | awk '{print $1}')"
		out_tok="$(echo "$tokens" | awk '{print $2}')"
		total_tok=$((in_tok + out_tok))

		if [[ "$status" == "succeeded" ]]; then
			echo "[batch-dispatcher] Batch succeeded. tokens=${total_tok}" >&2
			"$SCRIPTS_DIR/plan-db-safe.sh" update-task "$TASK_ID" done \
				"Batch completed (input=${in_tok}, output=${out_tok})" \
				--tokens "$total_tok" 2>/dev/null || true
			echo '{"status":"succeeded","batch_id":"'"$batch_id"'","task_id":'"$TASK_ID"',"tokens":'"$total_tok"'}'
		else
			echo "[batch-dispatcher] Batch errored. status=$status" >&2
			"$SCRIPTS_DIR/plan-db.sh" update-task "$TASK_ID" blocked \
				"Batch failed: status=$status" 2>/dev/null || true
			echo '{"status":"errored","batch_id":"'"$batch_id"'","task_id":'"$TASK_ID"'}' >&2
			exit 1
		fi
	else
		echo "[batch-dispatcher] Poll timed out for batch $batch_id" >&2
		"$SCRIPTS_DIR/plan-db.sh" update-task "$TASK_ID" blocked "Batch poll timeout" 2>/dev/null || true
		exit 1
	fi
}

main
