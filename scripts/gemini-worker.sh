#!/usr/bin/env bash
# Run Gemini worker for research/exploration tasks.
# Usage: gemini-worker.sh <db_task_id> [--timeout <seconds>] [--retries <count>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/delegate-utils.sh"
source "${SCRIPT_DIR}/lib/agent-protocol.sh"

TASK_DB_ID="${1:-}"
shift || true

TIMEOUT_SECONDS=900
MAX_RETRIES=4
MODEL="${GEMINI_MODEL:-gemini-2.5-pro}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--timeout)
		TIMEOUT_SECONDS="${2:?missing timeout value}"
		shift 2
		;;
	--retries)
		MAX_RETRIES="${2:?missing retries value}"
		shift 2
		;;
	*)
		shift
		;;
	esac
done

usage() {
	echo "Usage: gemini-worker.sh <db_task_id> [--timeout <seconds>] [--retries <count>]" >&2
}

timeout_cmd() {
	if command -v timeout >/dev/null 2>&1; then
		echo "timeout"
		return 0
	fi
	if command -v gtimeout >/dev/null 2>&1; then
		echo "gtimeout"
		return 0
	fi
	return 1
}

is_rate_limit_error() {
	local content="${1:-}"
	[[ "$content" =~ [Rr]ate[[:space:]_-]*limit ]] || [[ "$content" =~ (^|[^0-9])429([^0-9]|$) ]] ||
		[[ "$content" =~ [Qq]uota[[:space:]]+exceeded ]] || [[ "$content" =~ [Tt]oo[[:space:]]+many[[:space:]]+requests ]]
}

is_auth_error() {
	local content="${1:-}"
	[[ "$content" =~ [Uu]nauthori[sz]ed ]] || [[ "$content" =~ (^|[^0-9])401([^0-9]|$) ]] ||
		[[ "$content" =~ [Ff]orbidden ]] || [[ "$content" =~ [Aa]uth(entication)?[[:space:]_-]*(failed|required|error) ]] ||
		[[ "$content" =~ [Ll]ogin[[:space:]]+required ]] || [[ "$content" =~ [Aa][Pp][Ii][[:space:]_-]*key ]]
}

build_research_prompt() {
	local envelope_json="${1:?envelope_json required}"
	local spec_json="${2:?spec_json required}"
	local task_code title description wave_id test_criteria

	task_code="$(echo "$spec_json" | jq -r '.task_id')"
	title="$(echo "$spec_json" | jq -r '.title')"
	description="$(echo "$spec_json" | jq -r '.description')"
	wave_id="$(echo "$spec_json" | jq -r '.wave_id')"
	test_criteria="$(echo "$spec_json" | jq -r '.test_criteria')"

	cat <<PROMPT
# Research Task: ${task_code} (${title})

You are executing a research/exploration task using Gemini with large-context analysis.
Return only the final research output in markdown.

## Task
Wave: ${wave_id}
Description:
${description}

## Verification criteria
${test_criteria}

## Structured context envelope (large context allowed)
${envelope_json}

## Output requirements
- Focus on actionable, evidence-based findings.
- Include explicit file paths and concrete implementation guidance when relevant.
- Keep output concise but complete enough for downstream execution.
PROMPT
}

if [[ -z "$TASK_DB_ID" || ! "$TASK_DB_ID" =~ ^[0-9]+$ ]]; then
	usage
	exit 1
fi

if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ || ! "$MAX_RETRIES" =~ ^[0-9]+$ ]]; then
	echo "ERROR: --timeout and --retries must be numeric" >&2
	exit 1
fi

if ! check_cli_available "gemini"; then
	echo "ERROR: gemini CLI unavailable or auth check failed" >&2
	safe_update_task "$TASK_DB_ID" "blocked" "Gemini CLI unavailable or not authenticated"
	exit 1
fi

TASK_SPEC="$(read_task_spec "$TASK_DB_ID")"
if [[ -z "$TASK_SPEC" || "$TASK_SPEC" == "null" ]]; then
	echo "ERROR: Task $TASK_DB_ID not found" >&2
	exit 1
fi

PLAN_ID="$(echo "$TASK_SPEC" | jq -r '.plan_id')"
PROJECT_ID="$(echo "$TASK_SPEC" | jq -r '.project_id')"
TASK_CODE="$(echo "$TASK_SPEC" | jq -r '.task_id')"
WORKTREE_RAW="$(echo "$TASK_SPEC" | jq -r '.worktree_path')"
WORKTREE="${WORKTREE_RAW/#\~/$HOME}"
if [[ -z "$WORKTREE" || "$WORKTREE" == "null" ]]; then
	WORKTREE="$(pwd)"
fi

safe_update_task "$TASK_DB_ID" "in_progress" "Gemini research worker started"

ENVELOPE_JSON="$(build_task_envelope "$TASK_DB_ID")"
PROMPT="$(build_research_prompt "$ENVELOPE_JSON" "$TASK_SPEC")"
PROMPT_TOKENS="$(_ap_tokens "$PROMPT")"

RESEARCH_DIR="${WORKTREE}/.copilot-tracking/research"
mkdir -p "$RESEARCH_DIR"

STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_FILE="${RESEARCH_DIR}/${STAMP}-${TASK_CODE}-research.md"
ERR_FILE="${RESEARCH_DIR}/${STAMP}-${TASK_CODE}-research.err.log"

START_TS="$(date +%s)"
EXIT_CODE=1
ERROR_REASON="Gemini worker failed"
TMP_OUT="$(mktemp)"
TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_OUT" "$TMP_ERR"' EXIT

for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
	set +e
	if TO_CMD="$(timeout_cmd)"; then
		"$TO_CMD" "$TIMEOUT_SECONDS" gemini -p "$PROMPT" -q >"$TMP_OUT" 2>"$TMP_ERR"
	else
		gemini -p "$PROMPT" -q >"$TMP_OUT" 2>"$TMP_ERR"
	fi
	EXIT_CODE=$?
	set -e

	ERR_CONTENT="$(<"$TMP_ERR")"
	if [[ "$EXIT_CODE" -eq 0 ]]; then
		cp "$TMP_OUT" "$OUT_FILE"
		: >"$ERR_FILE"
		break
	fi

	cp "$TMP_ERR" "$ERR_FILE"
	if [[ "$EXIT_CODE" -eq 124 ]]; then
		ERROR_REASON="Gemini timeout after ${TIMEOUT_SECONDS}s"
		break
	fi
	if is_auth_error "$ERR_CONTENT"; then
		ERROR_REASON="Gemini authentication failed"
		break
	fi
	if is_rate_limit_error "$ERR_CONTENT"; then
		ERROR_REASON="Gemini rate limit reached"
		if ((attempt < MAX_RETRIES)); then
			sleep "$((2 ** attempt))"
			continue
		fi
		break
	fi

	ERROR_REASON="Gemini execution failed (exit ${EXIT_CODE})"
	break
done

END_TS="$(date +%s)"
DURATION_MS="$(((END_TS - START_TS) * 1000))"

if [[ "$EXIT_CODE" -eq 0 ]]; then
	RESPONSE_TOKENS="$(_ap_tokens "$(cat "$OUT_FILE")")"
	OUTPUT_DATA="$(jq -cn --arg summary "Saved Gemini research output to ${OUT_FILE}" --arg artifact "$OUT_FILE" '{summary:$summary,artifacts:[$artifact]}')"
	safe_update_task "$TASK_DB_ID" "done" "Gemini research worker completed" --tokens "$RESPONSE_TOKENS" --output-data "$OUTPUT_DATA"
	log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "gemini" "$MODEL" "$PROMPT_TOKENS" "$RESPONSE_TOKENS" "$DURATION_MS" 0 "PASS" 0 "public"
	echo "{\"status\":\"done\",\"task_id\":\"${TASK_CODE}\",\"output\":\"${OUT_FILE}\"}"
	exit 0
fi

log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "gemini" "$MODEL" "$PROMPT_TOKENS" 0 "$DURATION_MS" "$EXIT_CODE" "FAIL" 0 "public"
safe_update_task "$TASK_DB_ID" "blocked" "$ERROR_REASON"
echo "{\"status\":\"blocked\",\"task_id\":\"${TASK_CODE}\",\"reason\":\"${ERROR_REASON}\"}" >&2
exit "$EXIT_CODE"
