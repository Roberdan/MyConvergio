#!/bin/bash
# Test: project-audit.sh fixture-based checks and severity thresholds
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

REPO_ROOT="$(get_repo_root)"
AUDIT_SCRIPT="${REPO_ROOT}/scripts/project-audit.sh"
TEST_ROOT=""

create_common_fixture() {
  local root="$1"
  mkdir -p "$root/.husky" "$root/.github/workflows" "$root/scripts/quality" "$root/docs/adr" "$root/src"

  cat > "$root/CLAUDE.md" <<'EOF'
# Build
Use build command.
# Test
Use test command.
# Lint
Use lint command.
EOF

  cat > "$root/AGENTS.md" <<'EOF'
# Agents
Standard agent guidance.
EOF

  cat > "$root/.gitignore" <<'EOF'
node_modules
.env
dist
coverage
__pycache__
.env.local
*.pem
*.key
EOF

  cat > "$root/package.json" <<'EOF'
{
  "name": "fixture",
  "version": "1.0.0",
  "scripts": {
    "build": "echo build",
    "test": "echo test",
    "lint": "echo lint"
  },
  "devDependencies": {}
}
EOF

  cat > "$root/.github/workflows/ci.yml" <<'EOF'
name: ci
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo ok
EOF

  cat > "$root/.husky/pre-commit" <<'EOF'
#!/bin/sh
echo one
echo two
echo three
echo four
echo five
echo six
EOF

  cat > "$root/.husky/pre-push" <<'EOF'
#!/bin/sh
echo push
EOF

  cat > "$root/.husky/commit-msg" <<'EOF'
#!/bin/sh
echo msg
EOF

  cat > "$root/.prettierrc" <<'EOF'
{}
EOF

  cat > "$root/eslint.config.js" <<'EOF'
export default [];
EOF

  cat > "$root/scripts/quality/secrets-scan.sh" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat > "$root/scripts/quality/env-var-audit.sh" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat > "$root/scripts/debt-check.sh" <<'EOF'
#!/bin/sh
exit 0
EOF

  cat > "$root/.env.example" <<'EOF'
KEY=value
EOF

  cat > "$root/.github/pull_request_template.md" <<'EOF'
## Verification Evidence
- tested
EOF

  cat > "$root/docs/adr/INDEX.md" <<'EOF'
# ADR Index
EOF
}

create_p2_fixture() {
  local root="$1"
  create_common_fixture "$root"
  cat > "$root/src/p2.py" <<'EOF'
# c1
# c2
value = 1
value = 2
value = 3
value = 4
value = 5
value = 6
value = 7
value = 8
EOF
  cat > "$root/src/ignored.go" <<'EOF'
// c1
// c2
// c3
// c4
// c5
// c6
// c7
// c8
// c9
// c10
package main
EOF
}

create_p1_fixture() {
  local root="$1"
  create_common_fixture "$root"
  cat > "$root/src/p1.js" <<'EOF'
// c1
// c2
// c3
v1 = 1;
v2 = 2;
v3 = 3;
v4 = 4;
v5 = 5;
v6 = 6;
v7 = 7;
v8 = 8;
EOF
}

main() {
  echo "=== test-project-audit.sh ==="
  assert_executable "$AUDIT_SCRIPT" "project-audit.sh exists and is executable"
  assert_bash_syntax "$AUDIT_SCRIPT" "project-audit.sh bash -n"

  TEST_ROOT="$(mktemp -d)"
  trap 'rm -rf "$TEST_ROOT"' EXIT

  create_p2_fixture "$TEST_ROOT/p2"
  create_p1_fixture "$TEST_ROOT/p1"

  local p2_json p1_json
  p2_json="$("$AUDIT_SCRIPT" --project-root "$TEST_ROOT/p2" --json)"
  p1_json="$("$AUDIT_SCRIPT" --project-root "$TEST_ROOT/p1" --json)"

  if jq -e 'type == "object" and .tool == "project-audit"' >/dev/null <<<"$p2_json"; then
    pass "JSON output is valid object"
  else
    fail "JSON output is valid object"
  fi

  if jq -e '.checks.hardening.status == "pass" and .checks.hardening.failed == 0' >/dev/null <<<"$p2_json"; then
    pass "hardening-check.sh integration is included"
  else
    fail "hardening-check.sh integration is included"
  fi

  if jq -e '.summary.total_checks > 1 and (.checks.additional | length) > 0' >/dev/null <<<"$p2_json"; then
    pass "additional checks are executed"
  else
    fail "additional checks are executed"
  fi

  if jq -e '[.checks.additional[] | select((.pass == false) and .severity == "P2")] | length == 1' >/dev/null <<<"$p2_json"; then
    pass "P2 severity count is correct for >10% threshold"
  else
    fail "P2 severity count is correct for >10% threshold"
  fi

  if jq -e '[.checks.additional[] | select((.pass == false) and .severity == "P1")] | length == 0' >/dev/null <<<"$p2_json"; then
    pass "P1 severity count is zero for <=20% fixture"
  else
    fail "P1 severity count is zero for <=20% fixture"
  fi

  if jq -e '.checks.additional[] | select(.check == "token_aware_comment_density" and .severity == "P2" and .pass == false) | (.findings[]?.file | endswith("/src/p2.py"))' >/dev/null <<<"$p2_json"; then
    pass "Python # comments are detected"
  else
    fail "Python # comments are detected"
  fi

  if jq -e '[.checks.additional[] | select(.check == "token_aware_comment_density") | .findings[]?.file | endswith("/src/ignored.go")] | any | not' >/dev/null <<<"$p2_json"; then
    pass "unknown language files are skipped"
  else
    fail "unknown language files are skipped"
  fi

  if jq -e '.checks.additional[] | select(.check == "token_aware_comment_density" and .severity == "P1" and .pass == false) | (.findings[]?.file | endswith("/src/p1.js"))' >/dev/null <<<"$p1_json"; then
    pass "JS // comments trigger P1 above 20%"
  else
    fail "JS // comments trigger P1 above 20%"
  fi

  if jq -e '[.checks.additional[] | select((.pass == false) and .severity == "P1")] | length == 1' >/dev/null <<<"$p1_json"; then
    pass "P1 severity count is correct for >20% threshold"
  else
    fail "P1 severity count is correct for >20% threshold"
  fi

  exit_with_summary "project-audit"
}

main "$@"
