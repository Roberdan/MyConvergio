#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

PROFILE_FILE="$REPO_ROOT/config/agent-profiles.yaml"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$PROFILE_FILE" ]] || fail "config/agent-profiles.yaml must exist"
pass "agent profiles file exists"

python3 - <<'PY' || fail "agent profile schema validation failed"
import yaml

path = "config/agent-profiles.yaml"
profiles = yaml.safe_load(open(path, encoding="utf-8"))
required_roles = ("executor", "validator", "planner", "reviewer")

for role in required_roles:
    if role not in profiles:
        raise SystemExit(f"missing role: {role}")
    role_map = profiles[role]
    for key in ("rules", "references", "commands"):
        value = role_map.get(key)
        if not isinstance(value, list) or not value:
            raise SystemExit(f"{role}.{key} must be a non-empty list")

print("PASS")
PY

echo "[OK] T14-01 criteria satisfied"
