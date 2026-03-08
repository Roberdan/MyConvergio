#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

PROFILE_FILE="$REPO_ROOT/config/agent-profiles.yaml"
LOADER="$REPO_ROOT/scripts/lib/agent-context-loader.sh"
MAX_TOKENS=12000

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$PROFILE_FILE" ]] || fail "config/agent-profiles.yaml must exist"
[[ -f "$LOADER" ]] || fail "scripts/lib/agent-context-loader.sh must exist"
[[ -x "$LOADER" ]] || fail "scripts/lib/agent-context-loader.sh must be executable"

roles="$(
  python3 - "$PROFILE_FILE" <<'PY'
import sys
import yaml

profile_path = sys.argv[1]
data = yaml.safe_load(open(profile_path, encoding="utf-8")) or {}

if not isinstance(data, dict):
    raise SystemExit("agent-profiles.yaml must be a mapping")

if isinstance(data.get("roles"), dict):
    role_map = data["roles"]
else:
    metadata_keys = {"common", "defaults", "version", "schema"}
    role_map = {k: v for k, v in data.items() if k not in metadata_keys}

if not role_map:
    raise SystemExit("no roles found in agent-profiles.yaml")

for role in sorted(role_map.keys()):
    print(role)
PY
)" || fail "failed to parse roles from agent-profiles.yaml"

[[ -n "$roles" ]] || fail "role list from agent-profiles.yaml must not be empty"

echo "Role token budget check (max ${MAX_TOKENS} tokens)"
printf "%-16s %-10s %-8s %s\n" "ROLE" "TOKENS" "BYTES" "STATUS"

over_budget=0
while IFS= read -r role; do
  [[ -n "$role" ]] || continue
  output="$("$LOADER" "$role")"
  bytes="$(printf '%s' "$output" | wc -c | tr -d '[:space:]')"
  tokens=$(( (bytes + 3) / 4 ))

  if (( tokens > MAX_TOKENS )); then
    printf "%-16s %-10s %-8s %s\n" "$role" "$tokens" "$bytes" "OVER"
    over_budget=$((over_budget + 1))
  else
    printf "%-16s %-10s %-8s %s\n" "$role" "$tokens" "$bytes" "OK"
  fi
done <<<"$roles"

(( over_budget == 0 )) || fail "${over_budget} role(s) exceed ${MAX_TOKENS} tokens"

echo "PASS"
pass "all roles are within token budget"
