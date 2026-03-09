#!/usr/bin/env bash
# deploy-heartbeat-service.sh — Install mesh-heartbeat as boot-level service on local or remote hosts
# Usage: deploy-heartbeat-service.sh [local|m1mario|omarchy|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
PLIST_TEMPLATE="$CLAUDE_HOME/config/com.claude.mesh-heartbeat.plist"
SYSTEMD_TEMPLATE="$CLAUDE_HOME/config/mesh-heartbeat.service.template"
DAEMON_LABEL="com.claude.mesh-heartbeat"

C='\033[0;36m' G='\033[0;32m' R='\033[0;31m' N='\033[0m'
info() { echo -e "${C}[deploy]${N} $*"; }
ok() { echo -e "${G}[deploy]${N} $*"; }
err() { echo -e "${R}[deploy]${N} $*" >&2; }

install_macos_local() {
    local user home claude_home
    user="$(whoami)"
    home="$HOME"
    claude_home="$CLAUDE_HOME"

    info "Installing LaunchDaemon on local macOS ($user)..."

    # Unload old agent/daemon if present
    sudo launchctl bootout system/$DAEMON_LABEL 2>/dev/null || true
    launchctl unload "$home/Library/LaunchAgents/$DAEMON_LABEL.plist" 2>/dev/null || true

    # Generate plist with actual paths
    local plist="/Library/LaunchDaemons/$DAEMON_LABEL.plist"
    sed -e "s|__CLAUDE_HOME__|$claude_home|g" \
        -e "s|__USER_HOME__|$home|g" \
        -e "s|__USERNAME__|$user|g" \
        "$PLIST_TEMPLATE" | sudo tee "$plist" >/dev/null

    sudo chown root:wheel "$plist"
    sudo chmod 644 "$plist"
    sudo launchctl bootstrap system "$plist"

    sleep 2
    if sudo launchctl print system/$DAEMON_LABEL >/dev/null 2>&1; then
        ok "LaunchDaemon installed and running (boot-level, no login required)"
    else
        err "LaunchDaemon loaded but may not be running. Check: sudo launchctl print system/$DAEMON_LABEL"
    fi
}

install_macos_remote() {
    local ssh_alias="$1"
    local remote_user="$2"
    local remote_home="/Users/$remote_user"
    local remote_claude="$remote_home/.claude"

    info "Installing LaunchDaemon on $ssh_alias ($remote_user)..."

    # Sync heartbeat script + libs
    ssh "$ssh_alias" "mkdir -p '$remote_claude/scripts/lib' '$remote_claude/config' '$remote_claude/data'"
    rsync -az \
        "$CLAUDE_HOME/scripts/mesh-heartbeat.sh" \
        "$ssh_alias:$remote_claude/scripts/mesh-heartbeat.sh"
    rsync -az \
        "$CLAUDE_HOME/scripts/lib/peers.sh" \
        "$ssh_alias:$remote_claude/scripts/lib/peers.sh"
    rsync -az \
        "$CLAUDE_HOME/config/peers.conf" \
        "$ssh_alias:$remote_claude/config/peers.conf"

    # Ensure data dir and DB exist
    ssh "$ssh_alias" "mkdir -p '$remote_claude/data' && touch '$remote_claude/data/mesh-heartbeat.log'"
    ssh "$ssh_alias" "test -f '$remote_claude/data/dashboard.db' || sqlite3 '$remote_claude/data/dashboard.db' \"CREATE TABLE IF NOT EXISTS peer_heartbeats (peer_name TEXT PRIMARY KEY, last_seen INTEGER NOT NULL, load_json TEXT, capabilities TEXT, updated_at TEXT DEFAULT (datetime('now'))); CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY, status TEXT DEFAULT 'pending');\""

    # Generate and deploy plist
    local tmp_plist="/tmp/$DAEMON_LABEL.plist"
    sed -e "s|__CLAUDE_HOME__|$remote_claude|g" \
        -e "s|__USER_HOME__|$remote_home|g" \
        -e "s|__USERNAME__|$remote_user|g" \
        "$PLIST_TEMPLATE" > "$tmp_plist"

    scp -q "$tmp_plist" "$ssh_alias:/tmp/$DAEMON_LABEL.plist"
    rm -f "$tmp_plist"

    ssh -t "$ssh_alias" "
        sudo launchctl bootout system/$DAEMON_LABEL 2>/dev/null || true
        sudo mv /tmp/$DAEMON_LABEL.plist /Library/LaunchDaemons/$DAEMON_LABEL.plist
        sudo chown root:wheel /Library/LaunchDaemons/$DAEMON_LABEL.plist
        sudo chmod 644 /Library/LaunchDaemons/$DAEMON_LABEL.plist
        sudo launchctl bootstrap system /Library/LaunchDaemons/$DAEMON_LABEL.plist
    "

    sleep 2
    if ssh -t "$ssh_alias" "sudo launchctl print system/$DAEMON_LABEL >/dev/null 2>&1"; then
        ok "$ssh_alias: LaunchDaemon running (boot-level)"
    else
        err "$ssh_alias: LaunchDaemon may not be running"
    fi
}

install_linux_remote() {
    local ssh_alias="$1"
    local remote_user="$2"
    local remote_home="/home/$remote_user"
    local remote_claude="$remote_home/.claude"

    info "Installing systemd service on $ssh_alias ($remote_user)..."

    # Sync files
    ssh "$ssh_alias" "mkdir -p '$remote_claude/scripts/lib' '$remote_claude/config' '$remote_claude/data'"
    rsync -az \
        "$CLAUDE_HOME/scripts/mesh-heartbeat.sh" \
        "$ssh_alias:$remote_claude/scripts/mesh-heartbeat.sh"
    rsync -az \
        "$CLAUDE_HOME/scripts/lib/peers.sh" \
        "$ssh_alias:$remote_claude/scripts/lib/peers.sh"
    rsync -az \
        "$CLAUDE_HOME/config/peers.conf" \
        "$ssh_alias:$remote_claude/config/peers.conf"

    # Ensure data dir and DB
    ssh "$ssh_alias" "mkdir -p '$remote_claude/data' && touch '$remote_claude/data/mesh-heartbeat.log'"
    ssh "$ssh_alias" "test -f '$remote_claude/data/dashboard.db' || sqlite3 '$remote_claude/data/dashboard.db' \"CREATE TABLE IF NOT EXISTS peer_heartbeats (peer_name TEXT PRIMARY KEY, last_seen INTEGER NOT NULL, load_json TEXT, capabilities TEXT, updated_at TEXT DEFAULT (datetime('now'))); CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY, status TEXT DEFAULT 'pending');\""

    # Generate systemd unit with real paths
    local tmp_unit="/tmp/mesh-heartbeat.service"
    CLAUDE_HOME="$remote_claude" envsubst < "$SYSTEMD_TEMPLATE" > "$tmp_unit"
    # Override: use daemon (foreground) mode
    sed -i.bak "s|mesh-heartbeat.sh start|mesh-heartbeat.sh daemon|" "$tmp_unit"
    rm -f "$tmp_unit.bak"

    scp -q "$tmp_unit" "$ssh_alias:/tmp/mesh-heartbeat.service"
    rm -f "$tmp_unit"

    ssh "$ssh_alias" "
        mkdir -p ~/.config/systemd/user
        mv /tmp/mesh-heartbeat.service ~/.config/systemd/user/mesh-heartbeat.service
        systemctl --user daemon-reload
        systemctl --user enable --now mesh-heartbeat.service
    "

    # Enable linger so service runs without login
    ssh -t "$ssh_alias" "sudo loginctl enable-linger $remote_user"

    sleep 2
    if ssh "$ssh_alias" "systemctl --user is-active mesh-heartbeat.service" 2>/dev/null | grep -q active; then
        ok "$ssh_alias: systemd service active + linger enabled (runs at boot, no login needed)"
    else
        err "$ssh_alias: service may not be running. Check: systemctl --user status mesh-heartbeat.service"
    fi
}

# --- Main ---

target="${1:-all}"

case "$target" in
local|m3max)
    install_macos_local
    ;;
m1mario)
    install_macos_remote "mac-dev-ts" "mariodan"
    ;;
omarchy)
    install_linux_remote "omarchy-ts" "roberdan"
    ;;
all)
    install_macos_local
    install_macos_remote "mac-dev-ts" "mariodan"
    install_linux_remote "omarchy-ts" "roberdan"
    ;;
*)
    echo "Usage: $0 [local|m1mario|omarchy|all]"
    exit 1
    ;;
esac
