#!/usr/bin/env bash
# test-secret-scanner.sh: Test suite for secret-scanner.sh
# Tests detection of API keys, tokens, passwords, AWS creds
# Tests false positives and allowlist/ignore patterns
# Version: 1.0.0
# NOTE: Requires bash 4.0+ for associative arrays

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_SCANNER="$(cd "$SCRIPT_DIR/.." && pwd)/hooks/secret-scanner.sh"
TEST_DIR=""

setup() {
  TEST_DIR=$(mktemp -d); cd "$TEST_DIR"
  git init -q; git config user.email "test@test.com"; git config user.name "Test User"
}

cleanup() { [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"; }
trap cleanup EXIT

run_test() {
  local expect_block="$1"; local name="$2"; local file="$3"; local content="$4"
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "$content" > "$file"; git add "$file"
  
  local output exit_code=0
  output=$(bash "$SECRET_SCANNER" 2>&1) || exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    [ "$expect_block" = "allow" ] && { echo -e "${GREEN}✓ $name${NC}"; TESTS_PASSED=$((TESTS_PASSED + 1)); } || \
      { echo -e "${RED}✗ $name (expected block, got allow)${NC}"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
  else
    [ "$expect_block" = "block" ] && { echo -e "${GREEN}✓ $name${NC}"; TESTS_PASSED=$((TESTS_PASSED + 1)); } || \
      { echo -e "${RED}✗ $name (expected allow, got block)${NC}"; echo "  Error: $output" | head -1; TESTS_FAILED=$((TESTS_FAILED + 1)); }
  fi
  git rm --cached -f "$file" >/dev/null 2>&1 || git reset HEAD "$file" >/dev/null 2>&1 || true
  rm -f "$file"
}

main() {
  echo "==================================================================="
  echo "Running secret-scanner.sh Test Suite"
  echo "==================================================================="
  [ ! -f "$SECRET_SCANNER" ] && { echo -e "${RED}ERROR: secret-scanner.sh not found${NC}"; exit 1; }
  setup
  
  echo "--- Testing Secret Detection ---"
  run_test block "OpenAI API Key" "t1.js" 'const k = "sk-1234567890abcdefghij";'
  run_test block "OpenAI Project Key" "t2.js" 'const k = "sk-proj-abcdefgh12345678";'
  run_test block "GitHub Token" "t3.sh" 'TOKEN="ghp_1234567890abcdefghijklmnopqrstuv"'
  run_test block "GitHub OAuth" "t4.sh" 'OAUTH="gho_abcdefghijklmnopqrstuvwxyz123456"'
  run_test block "AWS Access Key" "t5.py" 'key = "AKIAIOSFODNN7EXAMPLE"'
  run_test block "AWS Secret Key" "t6.py" 'aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
  run_test block "Azure Storage Key" "t7.cs" 'key = "AccountKey=abcd1234EFGH5678ijkl9012MNOP3456qrst7890uvwxABCD1234EFGH5678ijkl9012MNOP3456qrst7890uv==";'
  run_test block "GCP API Key" "t8.js" 'const k = "AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe";'
  run_test block "Generic API Key" "t9.rb" 'api_key = "abcdefgh12345678"'
  run_test block "Generic Secret" "t10.py" 'secret = "my-super-secret-value-123"'
  run_test block "Generic Password" "t11.java" 'String password = "P@ssw0rd123!";'
  run_test block "Generic Token" "t12.ts" 'const token = "abcd-efgh-1234-5678-ijkl";'
  run_test block "JWT Token" "t13.js" 'jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U";'
  run_test block "Slack Token" "t14.sh" 'SLACK="xoxb-1234567890123-1234567890123-abcdefghijklmnopqrstuvwx"'
  run_test block "Stripe Secret" "t15.rb" 'key = "sk_live_abcdefghijklmnopqrstuvwx"'
  run_test block "Stripe Publishable" "t16.js" 'key = "pk_live_1234567890abcdefghijklmnopqrstuvwx";'
  run_test block "Private Key" "t17.pem" '-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890
-----END RSA PRIVATE KEY-----'
  run_test block "MongoDB Connection" "t18.js" 'uri = "mongodb://user:password@localhost:27017/db";'
  run_test block "PostgreSQL Connection" "t19.py" 'DB = "postgresql://user:pass@localhost:5432/mydb"'
  
  echo ""
  echo "--- Testing False Positives & Allowed Patterns ---"
  run_test allow "Variable Names" "t20.js" 'const apiKeyName = "user_api_key"; const secretType = "secret";'
  run_test allow "Comments" "t21.sh" '# Set your API_KEY environment variable
# Example: export API_KEY="your-key-here"'
  run_test allow "Env Var Usage JS" "t22.js" 'const key = process.env.API_KEY; const sec = process.env.SECRET_TOKEN;'
  run_test allow "Env Var Usage Bash" "t23.sh" 'API_KEY="${API_KEY}"; SECRET="${SECRET_TOKEN}"'
  run_test allow "Localhost Fallback Bash" "t24.sh" 'API_URL="${API_URL:-http://localhost:3000}"'
  run_test allow "Localhost Fallback JS" "t25.js" 'const url = process.env.API_URL || '\''http://localhost:3000'\'';'
  run_test allow "Lock File Ignored" "package-lock.json" '{"password": "would-normally-trigger"}'
  
  echo ""
  echo "--- Testing Hardcoded URLs & IPs (Should Block) ---"
  run_test block "Hardcoded Localhost" "t26.js" 'const url = "http://localhost:3000";'
  run_test block "Hardcoded IP" "t27.py" 'API_URL = "http://127.0.0.1:8080"'
  run_test block "External URL" "t28.js" 'const url = "https://api.realsite.com/v1";'
  
  echo ""
  echo "==================================================================="
  echo "Test Results: $TESTS_RUN total, ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"
  echo "==================================================================="
  
  [ $TESTS_FAILED -eq 0 ] && { echo -e "${GREEN}✓ All tests passed!${NC}"; exit 0; } || \
    { echo -e "${RED}✗ Some tests failed${NC}"; exit 1; }
}

main "$@"

