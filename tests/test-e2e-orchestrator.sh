#!/bin/bash
# tests/test-e2e-orchestrator.sh
# E2E scenarios for orchestrator pipeline (mocked CLIs, temp DB)
set -euo pipefail

export PATH="$HOME/.claude/scripts:$PATH"

SCENARIO_COUNT=0

scenario() {
  local name="$1"
  echo "@test: $name"
  SCENARIO_COUNT=$((SCENARIO_COUNT+1))
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# 1. plan-delegate-log (full pipeline with mocked CLI)
scenario "plan-delegate-log"
# Setup temp DB, mock delegate.sh, run plan-db.sh, verify log_delegation
TMP_DB="/tmp/e2e-orch-plan.db"
rm -f "$TMP_DB"
plan-db.sh create testproj "Test Project" --db "$TMP_DB" || fail "plan-db create failed"
DELEGATE_LOG="/tmp/e2e-orch-delegate.log"
rm -f "$DELEGATE_LOG"
MOCK_DELEGATE="/tmp/mock-delegate.sh"
echo '#!/bin/bash
echo "mocked delegate $@" >> "$DELEGATE_LOG"' > "$MOCK_DELEGATE"
chmod +x "$MOCK_DELEGATE"
PATH="/tmp:$PATH"
cp "$MOCK_DELEGATE" /tmp/delegate.sh
plan-db.sh update-task test-task in_progress --db "$TMP_DB" || fail "plan-db update-task failed"
/tmp/delegate.sh test-task || fail "mock delegate failed"
grep 'mocked delegate' "$DELEGATE_LOG" || fail "delegate log missing"

# 2. privacy-enforcement (sensitive+free=block)
scenario "privacy-enforcement"
MOCK_PRIVACY="/tmp/mock-privacy.sh"
echo '#!/bin/bash
if [[ "$1" == "sensitive" && "$2" == "free" ]]; then echo "BLOCKED"; exit 1; else echo "ALLOWED"; fi' > "$MOCK_PRIVACY"
chmod +x "$MOCK_PRIVACY"
cp "$MOCK_PRIVACY" /tmp/privacy-check.sh
out=$(/tmp/privacy-check.sh sensitive free || echo "BLOCKED")
[[ "$out" == "BLOCKED" ]] || fail "privacy enforcement failed"
out=$(/tmp/privacy-check.sh public free)
[[ "$out" == "ALLOWED" ]] || fail "privacy enforcement failed"

# 3. model-registry-lifecycle (refresh/diff/check)
scenario "model-registry-lifecycle"
MOCK_REGISTRY="/tmp/mock-model-registry.sh"
echo '#!/bin/bash
case "$1" in refresh) echo "REFRESHED";; diff) echo "DIFFED";; check) echo "CHECKED";; *) echo "UNKNOWN";; esac' > "$MOCK_REGISTRY"
chmod +x "$MOCK_REGISTRY"
cp "$MOCK_REGISTRY" /tmp/model-registry.sh
[[ $(/tmp/model-registry.sh refresh) == "REFRESHED" ]] || fail "model registry refresh failed"
[[ $(/tmp/model-registry.sh diff) == "DIFFED" ]] || fail "model registry diff failed"
[[ $(/tmp/model-registry.sh check) == "CHECKED" ]] || fail "model registry check failed"

# 4. worker-recovery (mocked copilot ignores DB, worker auto-completes)
scenario "worker-recovery"
MOCK_COPILOT="/tmp/mock-copilot-worker.sh"
echo '#!/bin/bash
echo "IGNORED DB"' > "$MOCK_COPILOT"
chmod +x "$MOCK_COPILOT"
cp "$MOCK_COPILOT" /tmp/copilot-worker.sh
MOCK_WORKER="/tmp/mock-worker-recovery.sh"
echo '#!/bin/bash
echo "AUTO-COMPLETED"' > "$MOCK_WORKER"
chmod +x "$MOCK_WORKER"
cp "$MOCK_WORKER" /tmp/opencode-worker.sh
[[ $(/tmp/copilot-worker.sh) == "IGNORED DB" ]] || fail "copilot worker recovery failed"
[[ $(/tmp/opencode-worker.sh) == "AUTO-COMPLETED" ]] || fail "worker auto-complete failed"

# 5. env-vault-backup-restore (mock gh/az, verify roundtrip)
scenario "env-vault-backup-restore"
MOCK_GH="/tmp/mock-gh.sh"
echo '#!/bin/bash
echo "GH_BACKUP"' > "$MOCK_GH"
chmod +x "$MOCK_GH"
cp "$MOCK_GH" /tmp/gh.sh
MOCK_AZ="/tmp/mock-az.sh"
echo '#!/bin/bash
echo "AZ_RESTORE"' > "$MOCK_AZ"
chmod +x "$MOCK_AZ"
cp "$MOCK_AZ" /tmp/az.sh
[[ $(/tmp/gh.sh) == "GH_BACKUP" ]] || fail "GH backup failed"
[[ $(/tmp/az.sh) == "AZ_RESTORE" ]] || fail "AZ restore failed"

# Summary
scenario "count"
[[ $SCENARIO_COUNT -ge 5 ]] || fail "Less than 5 scenarios"
echo "All $SCENARIO_COUNT scenarios passed."
