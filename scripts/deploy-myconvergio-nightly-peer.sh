#!/usr/bin/env bash
set -euo pipefail

# Deploy nightly guardian assets to a Linux peer and enable timer.
# Usage: deploy-myconvergio-nightly-peer.sh [peer-ssh-alias]
# Version: 1.0.0

PEER="${1:-omarchy-ts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { printf '[nightly-deploy] %s\n' "$*"; }

REQUIRED_FILES=(
  "${SCRIPT_DIR}/myconvergio-nightly-guardian.sh"
  "${SCRIPT_DIR}/install-myconvergio-nightly-linux.sh"
  "${REPO_ROOT}/config/myconvergio-nightly.conf.example"
  "${REPO_ROOT}/systemd/myconvergio-nightly-guardian.service"
  "${REPO_ROOT}/systemd/myconvergio-nightly-guardian.timer"
)

for file in "${REQUIRED_FILES[@]}"; do
  [[ -f "${file}" ]] || { log "Missing required file: ${file}"; exit 1; }
done

ssh -o BatchMode=yes -o ConnectTimeout=10 "${PEER}" \
  'mkdir -p "$HOME/GitHub/MyConvergio/scripts" "$HOME/GitHub/MyConvergio/systemd" "$HOME/GitHub/MyConvergio/config"'

scp -q \
  "${SCRIPT_DIR}/myconvergio-nightly-guardian.sh" \
  "${SCRIPT_DIR}/install-myconvergio-nightly-linux.sh" \
  "${SCRIPT_DIR}/deploy-myconvergio-nightly-peer.sh" \
  "${PEER}:~/GitHub/MyConvergio/scripts/"

scp -q \
  "${REPO_ROOT}/systemd/myconvergio-nightly-guardian.service" \
  "${REPO_ROOT}/systemd/myconvergio-nightly-guardian.timer" \
  "${PEER}:~/GitHub/MyConvergio/systemd/"

scp -q \
  "${REPO_ROOT}/config/myconvergio-nightly.conf.example" \
  "${PEER}:~/GitHub/MyConvergio/config/"

ssh "${PEER}" 'chmod +x "$HOME/GitHub/MyConvergio/scripts/myconvergio-nightly-guardian.sh" "$HOME/GitHub/MyConvergio/scripts/install-myconvergio-nightly-linux.sh" "$HOME/GitHub/MyConvergio/scripts/deploy-myconvergio-nightly-peer.sh"'
ssh "${PEER}" '"$HOME/GitHub/MyConvergio/scripts/install-myconvergio-nightly-linux.sh"'
ssh "${PEER}" 'systemctl --user --no-pager list-timers myconvergio-nightly-guardian.timer'

log "Deployment complete on ${PEER}"
