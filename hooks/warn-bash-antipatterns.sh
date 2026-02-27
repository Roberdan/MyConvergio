#!/bin/bash
# Warn when Claude uses bash commands that should be tool calls
# Hook type: PreToolUse on Bash
# Version: 1.2.0
set -uo pipefail

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

# zsh safety: != inside double-quoted sqlite3/SQL -> use <> or NOT IN
if echo "$COMMAND" | grep -qE 'sqlite3.*"[^"]*!=.*"' 2>/dev/null; then
	echo "BLOCKED: '!=' inside double-quoted sqlite3 command will break in zsh (! expansion)."
	echo "Fix: Use SQL '<>' operator or 'NOT IN (...)' instead of '!='."
	echo "Example: status <> 'done' OR status NOT IN ('done')"
	exit 2
fi

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

# Pipe to non-builtin without absolute path -> warn to use `which` first
# Builtins that don't need path: echo, printf, read, test, [, cd, export, etc.
BUILTINS="echo|printf|read|test|cd|export|set|unset|shift|return|exit|true|false|type|hash|alias|source|eval|exec|wait|trap|kill|jobs|bg|fg|times|umask|getopts|command|builtin|declare|local|typeset|readonly|let|ulimit|shopt|enable|mapfile|readarray|dirs|pushd|popd|suspend|logout|disown|coproc|compgen|complete|compopt"
if echo "$COMMAND" | grep -qE '\|' 2>/dev/null; then
	# Extract commands after pipes (strip leading whitespace)
	PIPED_CMDS=$(echo "$COMMAND" | tr '|' '\n' | tail -n +2 | sed 's/^ *//' | awk '{print $1}')
	for cmd in $PIPED_CMDS; do
		# Skip if absolute path, variable, or builtin
		[[ "$cmd" == /* ]] && continue
		[[ "$cmd" == \$* ]] && continue
		echo "$cmd" | grep -qE "^($BUILTINS)$" && continue
		# Warn: non-builtin piped without absolute path
		echo "WARNING: Piping to '$cmd' without absolute path. Run 'which $cmd' first or use absolute path."
		exit 0
	done
fi

exit 0
