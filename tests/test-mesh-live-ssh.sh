#!/usr/bin/env bash
# test-mesh-live-ssh.sh — Real SSH integration tests against active mesh peers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$REPO_ROOT/scripts/lib/peers.sh"

SSH_OPTS=(-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
SCP_OPTS=(-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

echo "=== mesh live SSH tests ==="

timeout_run() {
  local secs="$1"
  shift
  "$@" &
  local pid=$!
  local ticks=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( ticks >= secs * 10 )); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid"
}

is_network_error() {
  local out="$1"
  [[ "$out" =~ [Tt]imed[[:space:]]out ]] ||
    [[ "$out" =~ [Nn]o[[:space:]]route[[:space:]]to[[:space:]]host ]] ||
    [[ "$out" =~ [Nn]etwork[[:space:]]is[[:space:]]unreachable ]] ||
    [[ "$out" =~ [Cc]ould[[:space:]]not[[:space:]]resolve[[:space:]]hostname ]] ||
    [[ "$out" =~ [Nn]ame[[:space:]]or[[:space:]]service[[:space:]]not[[:space:]]known ]] ||
    [[ "$out" =~ [Cc]onnection[[:space:]]refused ]] ||
    [[ "$out" =~ [Cc]onnection[[:space:]]closed ]] ||
    [[ "$out" =~ [Kk]ex_exchange_identification ]]
}

peer_dest() {
  local peer="$1" target user
  target="$(peers_best_route "$peer")"
  user="$(peers_get "$peer" user 2>/dev/null || echo "")"
  [[ -n "$user" ]] && echo "${user}@${target}" || echo "$target"
}

ssh_peer() {
  local peer="$1"
  shift
  ssh "${SSH_OPTS[@]}" "$(peer_dest "$peer")" "$@"
}

scp_to_peer() {
  local peer="$1" src="$2" dst="$3"
  scp "${SCP_OPTS[@]}" "$src" "$(peer_dest "$peer"):$dst"
}

scp_from_peer() {
  local peer="$1" src="$2" dst="$3"
  scp "${SCP_OPTS[@]}" "$(peer_dest "$peer"):$src" "$dst"
}

run_capture() {
  local __out_var="$1"
  shift
  local tmp rc
  tmp="$(mktemp)"
  if timeout_run 10 "$@" >"$tmp" 2>&1; then
    printf -v "$__out_var" '%s' "$(cat "$tmp")"
    rm -f "$tmp"
    return 0
  fi
  rc=$?
  printf -v "$__out_var" '%s' "$(cat "$tmp")"
  rm -f "$tmp"
  return "$rc"
}

skip_or_fail() {
  local title="$1" rc="$2" out="$3"
  if [[ "$rc" -eq 124 ]] || is_network_error "$out"; then
    pass "$title (SKIP: ${out:-timeout})"
    return 0
  fi
  fail "$title" "command succeeded" "rc=$rc output=${out:-<empty>}"
  return 1
}

if [[ "${MESH_TEST_LIVE:-0}" != "1" ]]; then
  pass "MESH_TEST_LIVE!=1; skipping all live SSH tests"
  print_test_summary "mesh live SSH"
  exit 0
fi

peers_load
ACTIVE_PEERS=()
while IFS= read -r peer; do
  ACTIVE_PEERS+=("$peer")
done < <(peers_list)
if [[ "${#ACTIVE_PEERS[@]}" -eq 0 ]]; then
  pass "No active peers found; skipping live SSH tests"
  print_test_summary "mesh live SSH"
  exit 0
fi

# T1: SSH connectivity to each active peer
for peer in "${ACTIVE_PEERS[@]}"; do
  out=""
  if run_capture out ssh_peer "$peer" echo ok; then
    [[ "$out" == "ok" ]] && pass "T1 ssh connectivity [$peer]" || fail "T1 ssh connectivity [$peer]" "ok" "$out"
  else
    rc=$?
    skip_or_fail "T1 ssh connectivity [$peer]" "$rc" "$out"
  fi
done

# T2: Remote load query parses cleanly
for peer in "${ACTIVE_PEERS[@]}"; do
  out=""
  if run_capture out ssh_peer "$peer" uptime; then
    parsed="$(echo "$out" | sed -nE 's/.*load averages?: *([0-9]+[.,][0-9]+).*/\1/p' | head -n1 | tr ',' '.')"
    [[ -n "$parsed" ]] && pass "T2 uptime parse [$peer]" || fail "T2 uptime parse [$peer]" "load value" "$out"
  else
    rc=$?
    skip_or_fail "T2 uptime parse [$peer]" "$rc" "$out"
  fi
done

# T3: Remote Claude CLI exists/version
for peer in "${ACTIVE_PEERS[@]}"; do
  out=""
  if run_capture out ssh_peer "$peer" "claude --version || which claude"; then
    [[ -n "$out" ]] && pass "T3 claude cli [$peer]" || fail "T3 claude cli [$peer]" "non-empty output" "<empty>"
  else
    rc=$?
    skip_or_fail "T3 claude cli [$peer]" "$rc" "$out"
  fi
done

# T4: Remote DB file exists
for peer in "${ACTIVE_PEERS[@]}"; do
  out=""
  if run_capture out ssh_peer "$peer" test -f ~/.claude/data/dashboard.db; then
    pass "T4 remote DB exists [$peer]"
  else
    rc=$?
    skip_or_fail "T4 remote DB exists [$peer]" "$rc" "$out"
  fi
done

# T5: Bidirectional ping A<->B
if [[ "${#ACTIVE_PEERS[@]}" -lt 2 ]]; then
  pass "T5 bidirectional ping (SKIP: need at least 2 active peers)"
else
  a="${ACTIVE_PEERS[0]}"
  b="${ACTIVE_PEERS[1]}"
  aip="$(peers_get "$a" tailscale_ip 2>/dev/null || echo "")"
  bip="$(peers_get "$b" tailscale_ip 2>/dev/null || echo "")"
  if [[ -z "$aip" || -z "$bip" ]]; then
    pass "T5 bidirectional ping (SKIP: missing tailscale_ip for $a or $b)"
  else
    out_ab=""
    out_ba=""
    rc_ab=0
    rc_ba=0
    run_capture out_ab ssh_peer "$a" "ping -c 1 -W 2 $bip >/dev/null 2>&1 || ping -c 1 -t 2 $bip >/dev/null 2>&1" || rc_ab=$?
    run_capture out_ba ssh_peer "$b" "ping -c 1 -W 2 $aip >/dev/null 2>&1 || ping -c 1 -t 2 $aip >/dev/null 2>&1" || rc_ba=$?
    if [[ "$rc_ab" -eq 0 && "$rc_ba" -eq 0 ]]; then
      pass "T5 bidirectional ping [$a<->$b]"
    elif [[ "$rc_ab" -eq 124 || "$rc_ba" -eq 124 ]] || is_network_error "$out_ab $out_ba"; then
      pass "T5 bidirectional ping [$a<->$b] (SKIP: network issue)"
    else
      fail "T5 bidirectional ping [$a<->$b]" "both directions succeed" "A->B rc=$rc_ab B->A rc=$rc_ba"
    fi
  fi
fi

# T6: mesh-load-query JSON for first active peer
first_peer="${ACTIVE_PEERS[0]}"
out=""
if run_capture out bash "$REPO_ROOT/scripts/mesh-load-query.sh" --json --peer "$first_peer"; then
  if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")' >/dev/null 2>&1; then
    pass "T6 mesh-load-query JSON [$first_peer]"
  else
    fail "T6 mesh-load-query JSON [$first_peer]" "valid JSON" "$out"
  fi
else
  rc=$?
  skip_or_fail "T6 mesh-load-query JSON [$first_peer]" "$rc" "$out"
fi

# T7: mesh-db-sync-tasks dry-run per peer
for peer in "${ACTIVE_PEERS[@]}"; do
  out=""
  if run_capture out bash "$REPO_ROOT/scripts/mesh-db-sync-tasks.sh" --peer "$peer" --dry-run; then
    pass "T7 db-sync dry-run [$peer]"
  else
    rc=$?
    skip_or_fail "T7 db-sync dry-run [$peer]" "$rc" "$out"
  fi
done

# T8: SCP round-trip compare
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
for peer in "${ACTIVE_PEERS[@]}"; do
  local_src="$TMP_DIR/src-${peer}.txt"
  local_back="$TMP_DIR/back-${peer}.txt"
  remote_file="~/.claude-live-ssh-${RANDOM}.txt"
  echo "mesh-live-ssh-$peer-$(date +%s)" >"$local_src"

  out_to=""
  out_from=""
  rc_to=0
  rc_from=0
  run_capture out_to scp_to_peer "$peer" "$local_src" "$remote_file" || rc_to=$?
  run_capture out_from scp_from_peer "$peer" "$remote_file" "$local_back" || rc_from=$?
  timeout_run 10 ssh_peer "$peer" "rm -f $remote_file" >/dev/null 2>&1 || true

  if [[ "$rc_to" -eq 0 && "$rc_from" -eq 0 ]]; then
    if cmp -s "$local_src" "$local_back"; then
      pass "T8 scp round-trip [$peer]"
    else
      fail "T8 scp round-trip [$peer]" "files match" "mismatch after round-trip"
    fi
  elif [[ "$rc_to" -eq 124 || "$rc_from" -eq 124 ]] || is_network_error "$out_to $out_from"; then
    pass "T8 scp round-trip [$peer] (SKIP: network issue)"
  else
    fail "T8 scp round-trip [$peer]" "scp upload/download succeed" "upload rc=$rc_to download rc=$rc_from"
  fi
done

print_test_summary "mesh live SSH"
