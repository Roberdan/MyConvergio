#!/usr/bin/env bash
set -euo pipefail
# gh-auto-token.sh — PreToolUse hook: auto-inject GH_TOKEN based on repo path
# Reads gh-accounts.json mapping, resolves token via `gh auth token --user`
# NEVER calls `gh auth switch` — only sets GH_TOKEN env var
# Version: 1.0.0

CONFIG_FILE="$HOME/.claude/config/gh-accounts.json"
INPUT=$(cat)

# Fast path: if config missing, approve without env
if [[ ! -f "$CONFIG_FILE" ]]; then
	echo '{"result":"approve"}'
	exit 0
fi

# Extract command from hook input
COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    cmd = d.get('tool_input', {}).get('command', '')
    print(cmd)
except:
    print('')
" 2>/dev/null || echo "")

# Fast path: skip if command doesn't involve GitHub operations
if [[ -z "$COMMAND" ]]; then
	echo '{"result":"approve"}'
	exit 0
fi

# Check if command involves gh/git-push/pr-ops/wave-worktree/ci operations
NEEDS_TOKEN=0
case "$COMMAND" in
*gh\ *|*pr-ops*|*wave-worktree*|*ci-digest*|*ci-watch*|*pr-threads*|*pr-digest*|*service-digest*)
	NEEDS_TOKEN=1
	;;
*git\ push*|*git\ fetch*|*git\ pull*)
	NEEDS_TOKEN=1
	;;
esac

if [[ "$NEEDS_TOKEN" -eq 0 ]]; then
	echo '{"result":"approve"}'
	exit 0
fi

# Resolve working directory — use PWD
CWD="${PWD}"

# Read config and find matching path (longest prefix match)
ACCOUNT=$(python3 -c "
import json, os
config = json.load(open('$CONFIG_FILE'))
cwd = '$CWD'
home = os.path.expanduser('~')
best_match = ''
best_account = config.get('default_account') or ''
for m in config.get('mappings', []):
    path = m['path'].replace('~', home).rstrip('/')
    cwd_norm = cwd.rstrip('/')
    if cwd_norm == path or cwd_norm.startswith(path + '/'):
        if len(path) > len(best_match):
            best_match = path
            best_account = m['account']
print(best_account)
" 2>/dev/null || echo "")

# No matching account — approve without env
if [[ -z "$ACCOUNT" ]]; then
	echo '{"result":"approve"}'
	exit 0
fi

# Resolve token (NEVER switches global auth)
TOKEN=$(gh auth token --user "$ACCOUNT" 2>/dev/null || echo "")

if [[ -z "$TOKEN" ]]; then
	echo '{"result":"approve"}'
	exit 0
fi

# Inject GH_TOKEN into command environment
echo "{\"result\":\"approve\",\"env\":{\"GH_TOKEN\":\"$TOKEN\"}}"
