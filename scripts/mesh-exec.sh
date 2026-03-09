#!/usr/bin/env bash
set -euo pipefail
# mesh-exec.sh — Run a copilot/claude task on a remote mesh peer
# Usage: mesh-exec.sh <peer> <prompt-or-file> [--model MODEL] [--tool copilot|claude]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/peers.sh"
peers_load

PEER="${1:-}" PROMPT_ARG="${2:-}" MODEL="gpt-5.4" TOOL="copilot"
shift 2 || { echo "Usage: mesh-exec.sh <peer> <prompt-or-file> [--model M] [--tool copilot|claude]" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --tool) TOOL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[[ -z "$PEER" || -z "$PROMPT_ARG" ]] && { echo "Usage: mesh-exec.sh <peer> <prompt-or-file> [--model M] [--tool copilot|claude]" >&2; exit 1; }

if ! peers_check "$PEER" 2>/dev/null; then
  echo "ERROR: $PEER is offline" >&2; exit 1
fi

dest="$(peers_best_route "$PEER")"
user="$(peers_get "$PEER" "user" 2>/dev/null || echo "")"
gh_acct="$(peers_get "$PEER" "gh_account" 2>/dev/null || echo "")"
target="${user:+${user}@}${dest}"

# Build PATH + auth prefix
PREFIX="export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH"
[[ -n "$gh_acct" ]] && PREFIX="$PREFIX; gh auth switch --user $gh_acct 2>/dev/null || true"

# Resolve prompt: file or inline string
if [[ -f "$PROMPT_ARG" ]]; then
  REMOTE_PROMPT="/tmp/mesh-exec-prompt-$$.md"
  scp -q "$PROMPT_ARG" "${target}:${REMOTE_PROMPT}"
  PROMPT_CMD="cat $REMOTE_PROMPT"
  CLEANUP="rm -f $REMOTE_PROMPT"
else
  REMOTE_PROMPT="/tmp/mesh-exec-prompt-$$.md"
  echo "$PROMPT_ARG" | ssh -n "$target" "cat > $REMOTE_PROMPT"
  PROMPT_CMD="cat $REMOTE_PROMPT"
  CLEANUP="rm -f $REMOTE_PROMPT"
fi

# Build tool command
if [[ "$TOOL" == "claude" ]]; then
  EXEC_CMD="claude -p --model $MODEL --allowedTools bash,computer,edit,view \"\$($PROMPT_CMD)\""
else
  EXEC_CMD="copilot -p --model $MODEL --yolo --add-dir . \"\$($PROMPT_CMD)\""
fi

echo "▸ Running $TOOL ($MODEL) on $PEER..."
ssh -o ServerAliveInterval=30 "$target" "$PREFIX; cd ~/.claude && $EXEC_CMD; $CLEANUP"
echo "✓ Done on $PEER."
