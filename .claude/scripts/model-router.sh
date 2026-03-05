#!/usr/bin/env bash
# model-router.sh v1.0.0
# Route task to optimal model based on task-type, effort, and executor-agent.
# Output: JSON {"model":"...","reason":"...","batch_eligible":true/false}
set -euo pipefail

TASK_TYPE=""
EFFORT=""
EXECUTOR_AGENT=""
PLAN_ID=""

usage() {
	echo "Usage: $0 --task-type TYPE --effort LEVEL --executor-agent AGENT [--plan-id ID]" >&2
	echo "  TYPE:  chore|doc|documentation|test|feature|config|architecture" >&2
	echo "  LEVEL: 1|2|3" >&2
	echo "  AGENT: claude|copilot" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--task-type)
		TASK_TYPE="${2:-}"
		shift 2
		;;
	--effort)
		EFFORT="${2:-}"
		shift 2
		;;
	--executor-agent)
		EXECUTOR_AGENT="${2:-}"
		shift 2
		;;
	--plan-id)
		PLAN_ID="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		;;
	esac
done

[[ -z "$TASK_TYPE" ]] && {
	echo "Error: --task-type is required" >&2
	usage
}
[[ -z "$EFFORT" ]] && {
	echo "Error: --effort is required" >&2
	usage
}
[[ -z "$EXECUTOR_AGENT" ]] && {
	echo "Error: --executor-agent is required" >&2
	usage
}

if [[ "$EFFORT" != "1" && "$EFFORT" != "2" && "$EFFORT" != "3" ]]; then
	echo "Error: --effort must be 1, 2, or 3 (got: $EFFORT)" >&2
	exit 1
fi

if [[ "$EXECUTOR_AGENT" != "claude" && "$EXECUTOR_AGENT" != "copilot" ]]; then
	echo "Error: --executor-agent must be claude or copilot (got: $EXECUTOR_AGENT)" >&2
	exit 1
fi

MODEL=""
REASON=""
BATCH_ELIGIBLE="false"

# Determine if batch-eligible (effort=1 + light type + claude agent)
if [[ "$EXECUTOR_AGENT" == "claude" && "$EFFORT" == "1" ]]; then
	case "$TASK_TYPE" in
	chore | doc | documentation | test)
		BATCH_ELIGIBLE="true"
		;;
	esac
fi

# Decision tree
if [[ "$EXECUTOR_AGENT" == "copilot" ]]; then
	case "$EFFORT" in
	1)
		MODEL="gpt-4.1"
		REASON="copilot+effort1"
		;;
	2)
		MODEL="gpt-5.3-codex"
		REASON="copilot+effort2"
		;;
	3)
		MODEL="claude-opus-4.6-fast"
		REASON="copilot+effort3"
		;;
	esac
else
	# executor_agent=claude
	case "$TASK_TYPE" in
	chore | doc | documentation)
		if [[ "$EFFORT" == "1" ]]; then
			MODEL="haiku"
			REASON="${TASK_TYPE}+effort1"
		elif [[ "$EFFORT" == "3" ]]; then
			MODEL="opus"
			REASON="${TASK_TYPE}+effort3"
		else
			MODEL="sonnet"
			REASON="${TASK_TYPE}+effort${EFFORT}"
		fi
		;;
	test | config)
		if [[ "$EFFORT" -le 2 ]]; then
			MODEL="sonnet"
			REASON="${TASK_TYPE}+effort${EFFORT}"
		else
			MODEL="opus"
			REASON="${TASK_TYPE}+effort3"
		fi
		;;
	feature)
		if [[ "$EFFORT" -le 2 ]]; then
			MODEL="sonnet"
			REASON="feature+effort${EFFORT}"
		else
			MODEL="opus"
			REASON="feature+effort3"
		fi
		;;
	architecture)
		MODEL="opus"
		REASON="architecture"
		;;
	*)
		if [[ "$EFFORT" == "3" ]]; then
			MODEL="opus"
			REASON="effort3"
		else
			MODEL="sonnet"
			REASON="default"
		fi
		;;
	esac
fi

printf '{"model":"%s","reason":"%s","batch_eligible":%s}\n' \
	"$MODEL" "$REASON" "$BATCH_ELIGIBLE"
