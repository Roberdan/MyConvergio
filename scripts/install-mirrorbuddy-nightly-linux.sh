#!/usr/bin/env bash
set -euo pipefail
# Install/upgrade MirrorBuddy nightly guardian systemd user timer on Linux.
# Version: 1.0.0

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="mirrorbuddy-nightly-guardian.service"
TIMER_NAME="mirrorbuddy-nightly-guardian.timer"
CONFIG_FILE="$CLAUDE_HOME/config/mirrorbuddy-nightly.conf"
CONFIG_EXAMPLE="$CLAUDE_HOME/config/mirrorbuddy-nightly.conf.example"

log() { printf '[nightly-install] %s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { log "Missing command: $1"; exit 1; }; }

require_cmd systemctl
mkdir -p "$SYSTEMD_USER_DIR" "$CLAUDE_HOME/config" "$CLAUDE_HOME/systemd" "$CLAUDE_HOME/scripts"

for file in "$CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh" \
  "$CLAUDE_HOME/systemd/$SERVICE_NAME" \
  "$CLAUDE_HOME/systemd/$TIMER_NAME"; do
  [[ -f "$file" ]] || { log "Required file not found: $file"; exit 1; }
done

chmod +x "$CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh" "$CLAUDE_HOME/scripts/install-mirrorbuddy-nightly-linux.sh"
install -m 644 "$CLAUDE_HOME/systemd/$SERVICE_NAME" "$SYSTEMD_USER_DIR/$SERVICE_NAME"
install -m 644 "$CLAUDE_HOME/systemd/$TIMER_NAME" "$SYSTEMD_USER_DIR/$TIMER_NAME"

if [[ ! -f "$CONFIG_FILE" ]]; then
  if [[ -f "$CONFIG_EXAMPLE" ]]; then
    cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    log "Created $CONFIG_FILE from example. Edit it before first run."
  else
    log "Missing config example: $CONFIG_EXAMPLE"
    exit 1
  fi
fi

if command -v loginctl >/dev/null 2>&1; then
  loginctl enable-linger "$USER" >/dev/null 2>&1 || true
fi

systemctl --user daemon-reload
systemctl --user enable --now "$TIMER_NAME"

log "Installed and enabled $TIMER_NAME"
systemctl --user --no-pager status "$TIMER_NAME" | sed -n '1,18p'
systemctl --user --no-pager list-timers "$TIMER_NAME"

log "Dry-run command: $CLAUDE_HOME/scripts/mirrorbuddy-nightly-guardian.sh"
