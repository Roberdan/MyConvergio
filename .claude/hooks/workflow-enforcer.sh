#!/usr/bin/env bash
# workflow-enforcer.sh — Unified PreToolUse hook
# Replaces enforce-planner-workflow.sh with state-aware enforcement.
# Version: 1.0.0
set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // .toolArgs.command // ""' 2>/dev/null)

DB="$HOME/.claude/data/dashboard.db"
STATE_FILE="$HOME/.claude/data/workflow-state.json"

# === HARD BLOCKS (always active) ===

# Block EnterPlanMode
if [ "$TOOL_NAME" = "EnterPlanMode" ]; then
    echo '{"decision":"block","reason":"BLOCKED: Use Skill(skill=\"planner\") not EnterPlanMode. EnterPlanMode = no DB = broken tracking."}'
    exit 0
fi

# Only check Bash for command-based blocks
if [ "$TOOL_NAME" != "Bash" ] && [ "$TOOL_NAME" != "bash" ]; then
    # Check Edit/Write during active plan execution (step 4-8)
    if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ]; then
        if [ -f "$STATE_FILE" ]; then
            PHASE=$(jq -r '.phase // ""' "$STATE_FILE" 2>/dev/null)
            AGENT=$(echo "$INPUT" | jq -r '.metadata.agent_type // .agentType // ""' 2>/dev/null)
            # Block direct edits during execution unless we're a task-executor
            if [ "$PHASE" = "executing" ] && [ "$AGENT" != "task-executor" ] && [ "$AGENT" != "thor" ]; then
                echo '{"decision":"block","reason":"BLOCKED: During plan execution, use Skill(skill=\"execute\") to launch a task-executor. Direct edits bypass plan-db tracking, file locking, and Thor validation."}'
                exit 0
            fi
        fi
    fi
    exit 0
fi

[ -z "$COMMAND" ] && exit 0

# Allow safe wrappers
echo "$COMMAND" | grep -qE "plan-db-safe\.sh" && exit 0
echo "$COMMAND" | grep -qE "planner-create\.sh" && exit 0

# Skip git commits, echo, printf
echo "$COMMAND" | grep -qE "^(cd [^;]+(&& |; ))?git commit" && exit 0
echo "$COMMAND" | grep -qE "^(echo |printf )" && exit 0

FIRST_LINE=$(echo "$COMMAND" | head -1)

# Block: plan-db.sh create (must use planner-create.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+create[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: Use planner-create.sh (not plan-db.sh create). Requires 3 reviews first."}'
    exit 0
fi

# Block: plan-db.sh import (must use planner-create.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+import[[:space:]]"; then
    echo '{"decision":"block","reason":"BLOCKED: Use planner-create.sh import (not plan-db.sh import). Requires 3 reviews first."}'
    exit 0
fi

# Block: plan-db.sh update-task ... done (must use plan-db-safe.sh)
if echo "$FIRST_LINE" | grep -qE "(^|[;&|] *)plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]]done"; then
    echo '{"decision":"block","reason":"BLOCKED: Use plan-db-safe.sh (not plan-db.sh) to mark tasks done. plan-db-safe.sh sets status to submitted (Thor must validate to done)."}'
    exit 0
fi

# === STATE-AWARE ENFORCEMENT ===

# Track execution state transitions
if echo "$FIRST_LINE" | grep -qE "Skill.*execute"; then
    # Starting execution — set state
    mkdir -p "$(dirname "$STATE_FILE")"
    PLAN_ID=$(echo "$COMMAND" | grep -oE '[0-9]+' | head -1)
    echo "{\"phase\":\"executing\",\"plan_id\":\"$PLAN_ID\",\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$STATE_FILE"
fi

# Block wave merge without Thor validation
if echo "$FIRST_LINE" | grep -qE "wave-worktree\.sh[[:space:]]+merge"; then
    PLAN_ID=$(echo "$COMMAND" | grep -oE '[0-9]+' | head -1)
    if [ -n "$PLAN_ID" ] && [ -f "$DB" ]; then
        UNVALIDATED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE plan_id=$PLAN_ID AND status='submitted';" 2>/dev/null || echo "0")
        if [ "$UNVALIDATED" -gt 0 ] 2>/dev/null; then
            echo "{\"decision\":\"block\",\"reason\":\"BLOCKED: $UNVALIDATED tasks still in 'submitted' status (not Thor-validated). Run plan-db.sh validate-task for each before merging.\"}"
            exit 0
        fi
    fi
fi

# Block plan-db.sh complete without all tasks validated
if echo "$FIRST_LINE" | grep -qE "plan-db\.sh[[:space:]]+complete"; then
    PLAN_ID=$(echo "$COMMAND" | grep -oE '[0-9]+' | head -1)
    if [ -n "$PLAN_ID" ] && [ -f "$DB" ]; then
        NOT_DONE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE plan_id=$PLAN_ID AND status NOT IN ('done','validated','skipped','cancelled');" 2>/dev/null || echo "0")
        if [ "$NOT_DONE" -gt 0 ] 2>/dev/null; then
            echo "{\"decision\":\"block\",\"reason\":\"BLOCKED: $NOT_DONE tasks not done/validated. Cannot complete plan. Run plan-db.sh execution-tree $PLAN_ID to see status.\"}"
            exit 0
        fi
    fi
    # Clear execution state on completion
    rm -f "$STATE_FILE" 2>/dev/null
fi

exit 0
