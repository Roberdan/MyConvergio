#!/bin/bash
# Verify Before Claim - Warn when agents claim success without evidence
# PostToolUse hook - triggers after Bash/Write to detect unverified claims
# Version: 1.0.0
set -uo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name and output
TOOL=$(echo "$INPUT" | jq -r '.tool // empty' 2>/dev/null)
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)

# Only check Bash and Write tools
case "$TOOL" in
Bash | Write) ;;
*)
	exit 0
	;;
esac

# Exit if no output to analyze
[ -z "$TOOL_OUTPUT" ] && exit 0

# Claim patterns that suggest the agent is declaring success
CLAIM_PATTERNS=(
	"all tests pass"
	"tests pass"
	"tests are passing"
	"all tests are passing"
	"build successful"
	"build succeeded"
	"lint passed"
	"linting passed"
	"verification complete"
	"verified successfully"
	"validation complete"
	"validated successfully"
	"checks pass"
	"all checks pass"
	"ready to commit"
	"ready for commit"
	"implementation complete"
	"task complete"
	"completed successfully"
)

# Check if output contains any claim patterns
CLAIM_FOUND=""
for pattern in "${CLAIM_PATTERNS[@]}"; do
	if echo "$TOOL_OUTPUT" | grep -qiE "$pattern" 2>/dev/null; then
		CLAIM_FOUND="$pattern"
		break
	fi
done

# If no claim detected, exit early
[ -z "$CLAIM_FOUND" ] && exit 0

# Extract command from Bash tool (if applicable)
COMMAND=""
if [ "$TOOL" = "Bash" ]; then
	COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
fi

# Verification command patterns that provide evidence
VERIFY_PATTERNS=(
	"npm test"
	"npm run test"
	"yarn test"
	"pnpm test"
	"pytest"
	"python -m pytest"
	"jest"
	"vitest"
	"mocha"
	"cargo test"
	"go test"
	"dotnet test"
	"mvn test"
	"gradle test"
	"make test"
	"npm run build"
	"yarn build"
	"pnpm build"
	"make build"
	"cargo build"
	"go build"
	"dotnet build"
	"mvn compile"
	"gradle build"
	"eslint"
	"npm run lint"
	"yarn lint"
	"pnpm lint"
	"rubocop"
	"flake8"
	"pylint"
	"mypy"
	"tsc --noEmit"
	"cargo clippy"
	"golangci-lint"
	"shellcheck"
	"phpstan"
	"phpcs"
)

# Check if current command is a verification command
VERIFIED_NOW=""
if [ -n "$COMMAND" ]; then
	for verify_pattern in "${VERIFY_PATTERNS[@]}"; do
		if echo "$COMMAND" | grep -qF "$verify_pattern" 2>/dev/null; then
			VERIFIED_NOW="yes"
			break
		fi
	done
fi

# If verified now, no warning needed
[ -n "$VERIFIED_NOW" ] && exit 0

# Look for recent verification in session history
# Check last 20 commands from history file
HISTORY_FILE="${CLAUDE_SESSION_DIR:-$HOME/.claude/sessions/current}/bash_history"
RECENT_VERIFICATION=""

if [ -f "$HISTORY_FILE" ]; then
	# Get last 20 commands
	RECENT_CMDS=$(tail -20 "$HISTORY_FILE" 2>/dev/null || echo "")

	# Check if any recent command was a verification
	for verify_pattern in "${VERIFY_PATTERNS[@]}"; do
		if echo "$RECENT_CMDS" | grep -qF "$verify_pattern" 2>/dev/null; then
			RECENT_VERIFICATION="yes"
			break
		fi
	done
fi

# If recent verification found, no warning needed
[ -n "$RECENT_VERIFICATION" ] && exit 0

# No verification evidence found - emit warning
echo "⚠️  VERIFICATION WARNING ⚠️"
echo ""
echo "Claim detected: \"$CLAIM_FOUND\""
echo "No evidence of verification command in current session."
echo ""
echo "Before claiming success, please run actual verification:"
echo "  • npm test / pytest / cargo test / go test"
echo "  • npm run build / make build"
echo "  • npm run lint / eslint / pylint"
echo ""
echo "This ensures claims are backed by evidence, not assumptions."
echo ""

# Exit 0 (warning only, don't block)
exit 0
