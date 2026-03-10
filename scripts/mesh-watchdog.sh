#!/usr/bin/env bash
# mesh-watchdog.sh — Auto-heal daemon for Convergio Mesh
# Monitors daemon health on all mesh nodes, restarts if down,
# syncs binaries if outdated. Runs every 60s.
set -euo pipefail

PEERS_CONF="${HOME}/.claude/config/peers.conf"
DB_PATH="${HOME}/.claude/data/dashboard.db"
BINARY="${HOME}/.claude/rust/claude-core/target/release/claude-core"
CRSQLITE="${HOME}/.claude/lib/crsqlite/crsqlite"
LOG="/tmp/mesh-watchdog.log"
LOCAL_VERSION=$("$BINARY" --version 2>/dev/null || echo "unknown")

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# Get local Tailscale IP
LOCAL_IP=$(tailscale ip -4 2>/dev/null || echo "")

check_local_daemon() {
  if ! pgrep -f "claude-core daemon" > /dev/null 2>&1; then
    log "HEAL: Local daemon is DOWN — restarting"
    nohup "$BINARY" daemon start \
      --peers-conf "$PEERS_CONF" \
      --db-path "$DB_PATH" \
      --port 9420 \
      --crsqlite-path "$CRSQLITE" \
      >> /tmp/mesh-daemon.log 2>&1 &
    sleep 3
    if pgrep -f "claude-core daemon" > /dev/null 2>&1; then
      log "HEAL: Local daemon restarted successfully (PID $(pgrep -f 'claude-core daemon'))"
    else
      log "ERROR: Failed to restart local daemon"
    fi
  fi
}

check_local_dashboard() {
  if ! pgrep -f "claude-core serve" > /dev/null 2>&1; then
    log "HEAL: Dashboard server is DOWN — restarting"
    nohup "$BINARY" serve \
      --static-dir "${HOME}/.claude/scripts/dashboard_web" \
      >> /tmp/mesh-dashboard.log 2>&1 &
    sleep 2
    log "HEAL: Dashboard server restarted"
  fi
}

check_remote_daemon() {
  local host="$1"
  local ip="$2"
  local ssh_alias="$3"
  local os="$4"

  # Skip self
  [[ "$ip" == "$LOCAL_IP" ]] && return 0

  # Check if reachable via Tailscale
  if ! timeout 5 bash -c "echo > /dev/tcp/$ip/9420" 2>/dev/null; then
    log "WARN: $host ($ip) — daemon port 9420 unreachable"

    # Try SSH and restart
    if [[ -n "$ssh_alias" ]]; then
      local ext=""; [[ "$os" == "linux" ]] && ext=".so"
      log "HEAL: Attempting SSH restart of $host via $ssh_alias"
      ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_alias" \
        "pgrep -f 'claude-core daemon' || nohup ~/.claude/rust/claude-core/target/release/claude-core daemon start \
          --peers-conf ~/.claude/config/peers.conf \
          --db-path ~/.claude/data/dashboard.db \
          --port 9420 \
          --crsqlite-path ~/.claude/lib/crsqlite/crsqlite${ext} \
          > /tmp/mesh-daemon.log 2>&1 &" 2>/dev/null && \
        log "HEAL: Sent restart command to $host" || \
        log "ERROR: SSH to $host failed"
    fi
  fi
}

check_db_health() {
  # Ensure peer_heartbeats table exists and has load_json column
  local has_load=$(sqlite3 "$DB_PATH" "PRAGMA table_info(peer_heartbeats);" 2>/dev/null | grep -c "load_json" || echo "0")
  if [[ "$has_load" == "0" ]]; then
    log "HEAL: Adding load_json column to peer_heartbeats"
    sqlite3 "$DB_PATH" "ALTER TABLE peer_heartbeats ADD COLUMN load_json TEXT;" 2>/dev/null || true
  fi

  # Check for stale ghost peers (IP addresses instead of names)
  local ghosts=$(sqlite3 "$DB_PATH" "SELECT peer_name FROM peer_heartbeats WHERE peer_name LIKE '%:%' OR peer_name = 'mesh';" 2>/dev/null)
  if [[ -n "$ghosts" ]]; then
    log "HEAL: Removing ghost peers: $ghosts"
    sqlite3 "$DB_PATH" "DELETE FROM peer_heartbeats WHERE peer_name LIKE '%:%' OR peer_name = 'mesh';" 2>/dev/null || true
  fi
}

# Parse peers.conf and check each node
run_checks() {
  log "--- Watchdog cycle start ---"

  check_local_daemon
  check_local_dashboard
  check_db_health

  local current_section="" current_ip="" current_ssh="" current_os=""
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      # Process previous section
      if [[ -n "$current_section" && "$current_section" != "mesh" && -n "$current_ip" ]]; then
        check_remote_daemon "$current_section" "$current_ip" "$current_ssh" "$current_os"
      fi
      current_section="${BASH_REMATCH[1]}"
      current_ip="" current_ssh="" current_os=""
    elif [[ "$line" =~ ^tailscale_ip=(.+)$ ]]; then
      current_ip="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^ssh_alias=(.+)$ ]]; then
      current_ssh="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^os=(.+)$ ]]; then
      current_os="${BASH_REMATCH[1]}"
    fi
  done < "$PEERS_CONF"

  # Process last section
  if [[ -n "$current_section" && "$current_section" != "mesh" && -n "$current_ip" ]]; then
    check_remote_daemon "$current_section" "$current_ip" "$current_ssh" "$current_os"
  fi

  log "--- Watchdog cycle complete ---"
}

# Main
if [[ "${1:-}" == "--once" ]]; then
  run_checks
else
  log "Mesh watchdog started (interval: 60s)"
  while true; do
    run_checks
    sleep 60
  done
fi
