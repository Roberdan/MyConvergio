#!/bin/bash
# Warn when Claude uses bash commands that should be tool calls
# Hook type: PreToolUse on Bash

# Get command from stdin (Claude passes tool input as JSON)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Exit if no command
[ -z "$COMMAND" ] && exit 0

# Check patterns and suggest tools
check_pattern() {
    local pattern="$1"
    local tool="$2"
    if echo "$COMMAND" | grep -qE "$pattern" 2>/dev/null; then
        echo "ANTIPATTERN: Use $tool tool instead of bash"
        echo "Command: $COMMAND"
        return 0
    fi
    return 1
}

# File search patterns -> Glob
check_pattern "^find " "Glob" && exit 0
check_pattern " find " "Glob" && exit 0

# Content search patterns -> Grep
check_pattern "^grep " "Grep" && exit 0
check_pattern "^rg " "Grep" && exit 0
check_pattern " \| *grep " "Grep" && exit 0

# File reading patterns -> Read
check_pattern "^cat [^|<>]+$" "Read" && exit 0
check_pattern "^head " "Read" && exit 0
check_pattern "^tail " "Read" && exit 0

# File editing patterns -> Edit
check_pattern "^sed -i" "Edit" && exit 0
check_pattern "^sed .* -i" "Edit" && exit 0
check_pattern "^awk " "Edit" && exit 0

# File writing patterns -> Write
check_pattern "^echo .+>" "Write" && exit 0
check_pattern "^printf .+>" "Write" && exit 0
check_pattern "cat <<" "Write" && exit 0

exit 0
