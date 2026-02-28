#!/bin/bash
# Version: 1.1.0
# Remote tmux launcher for audit remediation plans
# Runs on the LINUX machine — creates 4 tmux windows, one per plan
set -euo pipefail

SESSION="audit-remediation"

# Resolve GH tokens for multi-account repos
MAIN_TOKEN=$(gh auth switch --user Roberdan 2>/dev/null && gh auth token 2>/dev/null || echo "")
gh auth switch --user roberdan_microsoft 2>/dev/null || true
VBPM_TOKEN=$(gh auth token 2>/dev/null || echo "")
gh auth switch --user Roberdan 2>/dev/null || true

# plan_id|project|label|dir|gh_token
PLANS=(
	"265|mirrorbuddy|MirrorBuddy|/home/roberdan/GitHub/MirrorBuddy|$MAIN_TOKEN"
	"266|virtualbpm|VirtualBPM|/home/roberdan/GitHub/VirtualBPM|$VBPM_TOKEN"
	"267|myconvergio|MyConvergio|/home/roberdan/GitHub/MyConvergio|$MAIN_TOKEN"
	"268|claude-global|Claude-Global|/home/roberdan/.claude|$MAIN_TOKEN"
)

# Kill existing session if any
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Create session with first plan
IFS='|' read -r pid project label dir token <<<"${PLANS[0]}"
tmux new-session -d -s "$SESSION" -n "$label" -c "$dir"
tmux send-keys -t "$SESSION:$label" \
	"export GH_TOKEN='$token' && echo '=== Plan #$pid: $label ===' && cd $dir && claude --dangerously-skip-permissions -p '/execute $pid'" Enter

# Create remaining windows
for i in 1 2 3; do
	IFS='|' read -r pid project label dir token <<<"${PLANS[$i]}"
	tmux new-window -t "$SESSION" -n "$label" -c "$dir"
	tmux send-keys -t "$SESSION:$label" \
		"export GH_TOKEN='$token' && echo '=== Plan #$pid: $label ===' && cd $dir && claude --dangerously-skip-permissions -p '/execute $pid'" Enter
done

# Create monitor window (5th tab)
tmux new-window -t "$SESSION" -n "Monitor" -c "/home/roberdan"
tmux send-keys -t "$SESSION:Monitor" \
	"export PATH=\"\$HOME/.claude/scripts:\$PATH\" && dashboard-mini.sh -r 30" Enter

# Select first window
tmux select-window -t "$SESSION:1"

echo "Tmux session '$SESSION' created with 5 windows:"
echo "  0: MirrorBuddy   (Plan #265) — GH: Roberdan"
echo "  1: VirtualBPM    (Plan #266) — GH: roberdan_microsoft"
echo "  2: MyConvergio   (Plan #267) — GH: Roberdan"
echo "  3: Claude-Global (Plan #268) — GH: Roberdan"
echo "  4: Monitor       (dashboard-mini auto-refresh 30s)"
echo ""
echo "Attach: tmux attach -t $SESSION"
