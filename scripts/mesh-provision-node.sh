#!/usr/bin/env bash
# mesh-provision-node.sh — Provision a new mesh node with all services
# Usage: mesh-provision-node.sh <peer-name> [--skip-build]
# Requires: peer defined in config/peers.conf, SSH access configured
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
source "$SCRIPT_DIR/lib/peers.sh"
peers_load

PEER="${1:?Usage: mesh-provision-node.sh <peer-name> [--skip-build]}"
SKIP_BUILD=false
[[ "${2:-}" == "--skip-build" ]] && SKIP_BUILD=true

C='\033[0;36m' G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' N='\033[0m'
ok()   { echo -e "${G}[✓]${N} $*"; }
info() { echo -e "${C}[→]${N} $*"; }
warn() { echo -e "${Y}[!]${N} $*"; }
fail() { echo -e "${R}[✗]${N} $*" >&2; exit 1; }

# Resolve peer info
DEST="$(peers_best_route "$PEER")"
USER="$(peers_get "$PEER" "user" 2>/dev/null || echo "")"
OS="$(peers_get "$PEER" "os" 2>/dev/null || echo "unknown")"
ROLE="$(peers_get "$PEER" "role" 2>/dev/null || echo "worker")"
GH_ACCT="$(peers_get "$PEER" "gh_account" 2>/dev/null || echo "")"
TARGET="${USER:+${USER}@}${DEST}"
REMOTE_HOME="$(ssh -n "$TARGET" 'echo $HOME')"

info "Provisioning $PEER ($OS, $ROLE) at $TARGET"

_ssh() { ssh -n -o ConnectTimeout=10 "$TARGET" "export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH; $*"; }

# 1. Git sync
info "Step 1/7: Git sync"
_ssh "cd ~/.claude && git fetch myconvergio main && git reset --hard myconvergio/main" && ok "Git synced" || fail "Git sync failed"

# 2. Build binary (unless skipped)
if ! $SKIP_BUILD; then
  info "Step 2/7: Building claude-core"
  _ssh "cd ~/.claude/rust/claude-core && cargo build --release 2>&1 | tail -3" && ok "Binary built" || fail "Build failed"
else
  warn "Step 2/7: Build skipped"
fi

# 3. Deploy crsqlite extension
info "Step 3/7: crsqlite extension"
if [[ "$OS" == "linux" ]]; then
  EXT_FILE="crsqlite.so"
  _ssh "test -f ~/.claude/lib/crsqlite/$EXT_FILE" && ok "crsqlite already present" || {
    _ssh "mkdir -p ~/.claude/lib/crsqlite"
    scp "$CLAUDE_HOME/lib/crsqlite/$EXT_FILE" "$TARGET:~/.claude/lib/crsqlite/" || {
      warn "SCP failed, downloading directly"
      _ssh "cd ~/.claude/lib/crsqlite && curl -sL https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-linux-x86_64.zip -o /tmp/crsql.zip && unzip -o /tmp/crsql.zip"
    }
    ok "crsqlite deployed"
  }
else
  EXT_FILE="crsqlite.dylib"
  _ssh "test -f ~/.claude/lib/crsqlite/$EXT_FILE" && ok "crsqlite already present" || {
    _ssh "mkdir -p ~/.claude/lib/crsqlite"
    scp "$CLAUDE_HOME/lib/crsqlite/$EXT_FILE" "$TARGET:~/.claude/lib/crsqlite/" || {
      warn "SCP failed, downloading directly"
      _ssh "cd ~/.claude/lib/crsqlite && curl -sL https://github.com/vlcn-io/cr-sqlite/releases/download/v0.16.3/crsqlite-darwin-aarch64.zip -o /tmp/crsql.zip && unzip -o /tmp/crsql.zip"
    }
    ok "crsqlite deployed"
  }
fi

# 4. Copy master DB (with CRR schemas) and reset site_id
info "Step 4/7: Database sync"
_ssh "cp ~/.claude/data/dashboard.db ~/.claude/data/dashboard.db.backup 2>/dev/null || true"
scp "$CLAUDE_HOME/data/dashboard.db" "$TARGET:~/.claude/data/dashboard.db"
_ssh "sqlite3 ~/.claude/data/dashboard.db 'DELETE FROM crsql_site_id;'"
ok "DB synced with fresh site_id"

# 5. Install daemon service
info "Step 5/7: CRDT daemon service"
CRSQL_EXT="$REMOTE_HOME/.claude/lib/crsqlite/$(echo $EXT_FILE | sed 's/\..*//')"
if [[ "$OS" == "linux" ]]; then
  _ssh "cat > ~/.config/systemd/user/claude-mesh-daemon.service << EOF
[Unit]
Description=Claude Mesh CRDT Daemon
After=network-online.target tailscaled.service
[Service]
ExecStart=$REMOTE_HOME/.claude/rust/claude-core/target/release/claude-core daemon start --peers-conf $REMOTE_HOME/.claude/config/peers.conf --db-path $REMOTE_HOME/.claude/data/dashboard.db --port 9420 --crsqlite-path $CRSQL_EXT
Restart=always
RestartSec=5
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable claude-mesh-daemon && systemctl --user restart claude-mesh-daemon"
else
  _ssh "cat > ~/Library/LaunchAgents/com.claude.mesh-daemon.plist << EOF
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
<key>Label</key><string>com.claude.mesh-daemon</string>
<key>ProgramArguments</key><array>
<string>$REMOTE_HOME/.claude/rust/claude-core/target/release/claude-core</string>
<string>daemon</string><string>start</string>
<string>--peers-conf</string><string>$REMOTE_HOME/.claude/config/peers.conf</string>
<string>--db-path</string><string>$REMOTE_HOME/.claude/data/dashboard.db</string>
<string>--port</string><string>9420</string>
<string>--crsqlite-path</string><string>$CRSQL_EXT</string>
</array>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>StandardOutPath</key><string>/tmp/claude-daemon.log</string>
<key>StandardErrorPath</key><string>/tmp/claude-daemon.log</string>
</dict></plist>
EOF
launchctl unload ~/Library/LaunchAgents/com.claude.mesh-daemon.plist 2>/dev/null; launchctl load ~/Library/LaunchAgents/com.claude.mesh-daemon.plist"
fi
ok "Daemon service installed and started"

# 6. Install heartbeat service
info "Step 6/7: Heartbeat service"
if [[ "$OS" == "linux" ]]; then
  _ssh "test -f ~/.config/systemd/user/mesh-heartbeat.service" && ok "Heartbeat already installed" || {
    _ssh "cat > ~/.config/systemd/user/mesh-heartbeat.service << EOF
[Unit]
Description=Claude Mesh Heartbeat
After=network-online.target
[Service]
ExecStart=$REMOTE_HOME/.claude/scripts/mesh-heartbeat.sh start
Restart=always
Environment=HOME=$REMOTE_HOME CLAUDE_HOME=$REMOTE_HOME/.claude PATH=/usr/local/bin:/usr/bin:/bin
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable mesh-heartbeat && systemctl --user restart mesh-heartbeat"
    ok "Heartbeat installed"
  }
else
  _ssh "launchctl list | grep -q mesh-heartbeat" && ok "Heartbeat already installed" || {
    _ssh "rm -f ~/.claude/data/mesh-heartbeat.pid; cat > ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist << EOF
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\"><dict>
<key>Label</key><string>com.claude.mesh-heartbeat</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>$REMOTE_HOME/.claude/scripts/mesh-heartbeat.sh</string><string>start</string></array>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>StandardOutPath</key><string>$REMOTE_HOME/.claude/logs/mesh-heartbeat.log</string>
<key>StandardErrorPath</key><string>$REMOTE_HOME/.claude/logs/mesh-heartbeat.log</string>
<key>EnvironmentVariables</key><dict>
<key>HOME</key><string>$REMOTE_HOME</string>
<key>CLAUDE_HOME</key><string>$REMOTE_HOME/.claude</string>
<key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
</dict></dict></plist>
EOF
launchctl load ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist"
    ok "Heartbeat installed"
  }
fi

# 7. Verify
info "Step 7/7: Verification"
sleep 3
DAEMON_OK=$(_ssh "ps aux | grep 'claude-core daemon' | grep -v grep | wc -l" 2>/dev/null)
HB_OK=$(_ssh "ps aux | grep 'mesh-heartbeat' | grep -v grep | wc -l" 2>/dev/null)
DB_PLANS=$(_ssh "sqlite3 ~/.claude/data/dashboard.db 'SELECT COUNT(*) FROM plans;'" 2>/dev/null)
TOOLS=$(_ssh "which copilot claude 2>/dev/null | wc -l" 2>/dev/null)

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Node Provisioning Summary        ║"
echo "╠══════════════════════════════════════╣"
printf "║ %-20s %15s ║\n" "Peer:" "$PEER"
printf "║ %-20s %15s ║\n" "OS:" "$OS"
printf "║ %-20s %15s ║\n" "Role:" "$ROLE"
printf "║ %-20s %15s ║\n" "CRDT Daemon:" "$([[ $DAEMON_OK -gt 0 ]] && echo '✅ running' || echo '❌ down')"
printf "║ %-20s %15s ║\n" "Heartbeat:" "$([[ $HB_OK -gt 0 ]] && echo '✅ running' || echo '❌ down')"
printf "║ %-20s %15s ║\n" "DB Plans:" "$DB_PLANS"
printf "║ %-20s %15s ║\n" "AI Tools:" "$TOOLS/2"
echo "╚══════════════════════════════════════╝"

[[ $DAEMON_OK -gt 0 && $HB_OK -gt 0 ]] && ok "Node $PEER fully provisioned!" || warn "Some services failed — check logs"
