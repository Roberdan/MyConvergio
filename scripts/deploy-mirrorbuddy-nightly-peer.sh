#!/usr/bin/env bash
set -euo pipefail
# Deploy nightly guardian assets to a Linux peer and enable timer.
# Usage: deploy-mirrorbuddy-nightly-peer.sh [peer-ssh-alias]
# Version: 1.0.0

PEER="${1:-omarchy-ts}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
REMOTE_CLAUDE_HOME='~/.claude'

log() { printf '[nightly-deploy] %s\n' "$*"; }

for file in \
  "$CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh" \
  "$CLAUDE_HOME/scripts/install-mirrorbuddy-nightly-linux.sh" \
  "$CLAUDE_HOME/config/mirrorbuddy-nightly.conf.example" \
  "$CLAUDE_HOME/systemd/mirrorbuddy-nightly-guardian.service" \
  "$CLAUDE_HOME/systemd/mirrorbuddy-nightly-guardian.timer"; do
  [[ -f "$file" ]] || { log "Missing required file: $file"; exit 1; }
done

ssh -o BatchMode=yes -o ConnectTimeout=10 "$PEER" \
  "mkdir -p $REMOTE_CLAUDE_HOME/scripts $REMOTE_CLAUDE_HOME/systemd $REMOTE_CLAUDE_HOME/config"

scp -q "$CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh" \
  "$CLAUDE_HOME/scripts/install-mirrorbuddy-nightly-linux.sh" \
  "$PEER:$REMOTE_CLAUDE_HOME/scripts/"
scp -q "$CLAUDE_HOME/systemd/mirrorbuddy-nightly-guardian.service" \
  "$CLAUDE_HOME/systemd/mirrorbuddy-nightly-guardian.timer" \
  "$PEER:$REMOTE_CLAUDE_HOME/systemd/"
scp -q "$CLAUDE_HOME/config/mirrorbuddy-nightly.conf.example" \
  "$PEER:$REMOTE_CLAUDE_HOME/config/"

ssh "$PEER" "chmod +x $REMOTE_CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh $REMOTE_CLAUDE_HOME/scripts/install-mirrorbuddy-nightly-linux.sh"
ssh "$PEER" "$REMOTE_CLAUDE_HOME/scripts/install-mirrorbuddy-nightly-linux.sh"
ssh "$PEER" "systemctl --user --no-pager list-timers mirrorbuddy-nightly-guardian.timer"

log "Deployment complete on $PEER"
