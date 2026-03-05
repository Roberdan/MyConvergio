#!/bin/bash
# Version: 1.0.0
# Mac-side orchestrator: sync DB + specs to Linux, launch tmux, start monitoring
set -euo pipefail

REMOTE="omarchy-ts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
REMOTE_DB="~/.claude/data/dashboard.db"

echo "=== Audit Remediation — Remote Launch ==="
echo ""

# Step 1: Push plan DB to Linux
echo "[1/5] Syncing plan DB to Linux..."
scp "$DB_FILE" "${REMOTE}:${REMOTE_DB}"
echo "  DB synced."

# Step 2: Sync spec files to Linux
echo "[2/5] Syncing spec files..."
scp "$HOME/GitHub/MirrorBuddy/.claude/plans/mirrorbuddy-audit-remediation-spec.yaml" \
	"${REMOTE}:~/GitHub/MirrorBuddy/.claude/plans/"
scp "$HOME/GitHub/VirtualBPM/.claude/plans/virtualbpm-audit-remediation-spec.yaml" \
	"${REMOTE}:~/GitHub/VirtualBPM/.claude/plans/"
scp "$HOME/GitHub/MyConvergio/.claude/plans/myconvergio-audit-remediation-spec.yaml" \
	"${REMOTE}:~/GitHub/MyConvergio/.claude/plans/"
scp "$HOME/.claude/plans/claude-global-audit-remediation-spec.yaml" \
	"${REMOTE}:~/.claude/plans/"
echo "  Specs synced."

# Step 3: Sync prompt files
echo "[3/5] Syncing prompt files..."
scp "$HOME/GitHub/MirrorBuddy/.claude/prompts/audit-remediation-2026-02-28.md" \
	"${REMOTE}:~/GitHub/MirrorBuddy/.claude/prompts/"
scp "$HOME/GitHub/VirtualBPM/.claude/prompts/audit-remediation-2026-02-28.md" \
	"${REMOTE}:~/GitHub/VirtualBPM/.claude/prompts/"
scp "$HOME/GitHub/MyConvergio/.claude/prompts/audit-remediation-2026-02-28.md" \
	"${REMOTE}:~/GitHub/MyConvergio/.claude/prompts/"
scp "$HOME/.claude/prompts/audit-remediation-2026-02-28.md" \
	"${REMOTE}:~/.claude/prompts/"
echo "  Prompts synced."

# Step 4: Copy launch script and run on Linux
echo "[4/5] Launching tmux on Linux..."
scp "$SCRIPT_DIR/audit-remote-launch.sh" "${REMOTE}:~/.claude/scripts/"
ssh "$REMOTE" "chmod +x ~/.claude/scripts/audit-remote-launch.sh && ~/.claude/scripts/audit-remote-launch.sh"

# Step 5: Start local autosync for monitoring
echo "[5/5] Starting local DB autosync..."
if command -v "$SCRIPT_DIR/plan-db.sh" &>/dev/null; then
	"$SCRIPT_DIR/plan-db.sh" autosync start 2>/dev/null || true
fi

echo ""
echo "=== Launch Complete ==="
echo ""
echo "Monitoring commands (run from Mac):"
echo "  piani                          # Dashboard interattiva"
echo "  piani -r 30                    # Auto-refresh ogni 30s"
echo "  ssh $REMOTE 'tmux attach -t audit-remediation'  # Attach alla sessione Linux"
echo ""
echo "Tmux navigation (dopo attach):"
echo "  Ctrl+B 0  → MirrorBuddy  (#265)"
echo "  Ctrl+B 1  → VirtualBPM   (#266)"
echo "  Ctrl+B 2  → MyConvergio  (#267)"
echo "  Ctrl+B 3  → Claude-Global(#268)"
echo "  Ctrl+B 4  → Monitor"
