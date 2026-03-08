#!/usr/bin/env bash
set -euo pipefail

# Install/upgrade MyConvergio nightly guardian systemd user timer on Linux.
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYSTEMD_SRC_DIR="${REPO_ROOT}/systemd"
CONFIG_DIR="${REPO_ROOT}/config"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SERVICE_NAME="myconvergio-nightly-guardian.service"
TIMER_NAME="myconvergio-nightly-guardian.timer"
CONFIG_EXAMPLE="${CONFIG_DIR}/myconvergio-nightly.conf.example"
CONFIG_FILE="${CONFIG_DIR}/myconvergio-nightly.conf"
GUARDIAN_SCRIPT="${SCRIPT_DIR}/myconvergio-nightly-guardian.sh"
INSTALL_SCRIPT="${SCRIPT_DIR}/install-myconvergio-nightly-linux.sh"

log() { printf '[nightly-install] %s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { log "Missing command: $1"; exit 1; }; }

require_cmd systemctl
mkdir -p "${SYSTEMD_USER_DIR}"

for file in \
  "${GUARDIAN_SCRIPT}" \
  "${SYSTEMD_SRC_DIR}/${SERVICE_NAME}" \
  "${SYSTEMD_SRC_DIR}/${TIMER_NAME}" \
  "${CONFIG_EXAMPLE}"; do
  [[ -f "${file}" ]] || { log "Required file not found: ${file}"; exit 1; }
done

chmod +x "${GUARDIAN_SCRIPT}" "${INSTALL_SCRIPT}"
install -m 644 "${SYSTEMD_SRC_DIR}/${SERVICE_NAME}" "${SYSTEMD_USER_DIR}/${SERVICE_NAME}"
install -m 644 "${SYSTEMD_SRC_DIR}/${TIMER_NAME}" "${SYSTEMD_USER_DIR}/${TIMER_NAME}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  cp "${CONFIG_EXAMPLE}" "${CONFIG_FILE}"
  log "Created ${CONFIG_FILE} from example."
fi

if command -v loginctl >/dev/null 2>&1; then
  loginctl enable-linger "${USER}" >/dev/null 2>&1 || true
fi

systemctl --user daemon-reload
systemctl --user enable --now "${TIMER_NAME}"

log "Installed and enabled ${TIMER_NAME}"
systemctl --user --no-pager status "${TIMER_NAME}"
systemctl --user --no-pager list-timers "${TIMER_NAME}"
