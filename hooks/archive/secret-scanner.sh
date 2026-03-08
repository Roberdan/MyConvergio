#!/usr/bin/env bash
# secret-scanner.sh — Copilot CLI preToolUse hook
# Scans staged files for secrets/hardcoded values before git commit.
# Version: 1.0.0

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)
if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" && "$TOOL_NAME" != "Bash" ]]; then
	exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.toolArgs.command // .tool_input.command // ""' 2>/dev/null)
if ! echo "$COMMAND" | grep -qE '(^|[;&[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
	exit 0
fi

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any secrets found
SECRETS_FOUND=0

# API Keys and Tokens patterns
declare -A SECRET_PATTERNS=(
  ["OpenAI API Key"]='sk-(proj-)?[a-zA-Z0-9]{8,}'
  ["GitHub Token"]='gh[pso]_[a-zA-Z0-9]{8,}|(ghu|ghs)_[a-zA-Z0-9]{8,}'
  ["AWS Access Key"]='AKIA[0-9A-Z]{16}'
  ["AWS Secret Key"]='aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{40}'
  ["Azure Storage Key"]='AccountKey=[A-Za-z0-9+/=]{88}'
  ["GCP API Key"]='AIza[0-9A-Za-z_-]{35}'
  ["Generic API Key"]='[aA][pP][iI][-_]?[kK][eE][yY][[:space:]]*[:=][[:space:]]*["'\''][a-zA-Z0-9_-]{8,}["'\'']'
  ["Generic Secret"]='[sS][eE][cC][rR][eE][tT][[:space:]]*[:=][[:space:]]*["'\''][a-zA-Z0-9_-]{8,}["'\'']'
  ["Generic Password"]='[pP][aA][sS][sS][wW][oO][rR][dD][[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}["'\'']'
  ["Generic Token"]='[tT][oO][kK][eE][nN][[:space:]]*[:=][[:space:]]*["'\''][a-zA-Z0-9_.-]{8,}["'\'']'
  ["JWT Token"]='eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}'
  ["Slack Token"]='xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24,}'
  ["Stripe Key"]='sk_live_[0-9a-zA-Z]{24,}'
  ["Stripe Publishable"]='pk_live_[0-9a-zA-Z]{24,}'
  ["Private Key"]='-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
  ["Connection String"]='(mongodb|mysql|postgresql|postgres|redis)://[^@]+:[^@]+@'
)

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")

if [ -z "$STAGED_FILES" ]; then
	# No staged files, allow command
	exit 0
fi

# Function to report secret found
report_secret() {
  local file="$1"
  local line_num="$2"
  local pattern_name="$3"
  local line_content="$4"
  
	echo -e "${RED}[BLOCKED] Secret detected: $pattern_name${NC}" >&2
	echo "  File: $file" >&2
	echo "  Line $line_num: $line_content" >&2
	echo "" >&2
	SECRETS_FOUND=1
}

# Function to scan file for secret patterns
scan_secrets() {
  local file="$1"
  
  # Skip binary files
  if file "$file" 2>/dev/null | grep -q "text"; then
    :
  else
    return 0
  fi
  
  # Skip lock files and generated files
  case "$file" in
    *.lock|package-lock.json|yarn.lock|Gemfile.lock|poetry.lock|*.min.js|*.min.css)
      return 0
      ;;
  esac
  
  # Check each secret pattern
  for pattern_name in "${!SECRET_PATTERNS[@]}"; do
    local pattern="${SECRET_PATTERNS[$pattern_name]}"
    
    while IFS=: read -r line_num line_content; do
      if [ -n "$line_num" ]; then
        report_secret "$file" "$line_num" "$pattern_name" "$line_content"
      fi
    done < <(grep -nE "$pattern" "$file" 2>/dev/null || true)
  done
}

# Function to check for hardcoded URLs (non-localhost)
scan_hardcoded_urls() {
  local file="$1"
  
  # Skip binary files
  if ! file "$file" 2>/dev/null | grep -q "text"; then
    return 0
  fi
  
  # Pattern for hardcoded URLs with real domains (not localhost, not env vars)
  # Exclude URLs that are clearly in comments or documentation
  while IFS=: read -r line_num line_content; do
    # Skip if line is a comment
    if echo "$line_content" | grep -qE '^\s*(#|//|/\*|\*)'; then
      continue
    fi
    
    # Skip if URL is in an environment variable reference
    if echo "$line_content" | grep -qE '\$\{[^}]*URL'; then
      continue
    fi
    
    # Skip if it's process.env or similar
    if echo "$line_content" | grep -qE '(process\.env|ENV\[|os\.getenv|System\.getenv)'; then
      continue
    fi
    
    if [ -n "$line_num" ]; then
			echo -e "${RED}[BLOCKED] Hardcoded URL detected${NC}" >&2
			echo "  File: $file" >&2
			echo "  Line $line_num: $line_content" >&2
			echo "  Use environment variables instead: process.env.API_URL or \${API_URL}" >&2
			echo "" >&2
			SECRETS_FOUND=1
    fi
  done < <(grep -nE 'https?://[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}[^"'\'' ]*' "$file" 2>/dev/null | \
           grep -v 'localhost' | \
           grep -v '127\.0\.0\.1' | \
           grep -v 'example\.com' | \
           grep -v 'test\.com' | \
           grep -v 'schema' | \
           grep -v '\.org/[0-9]' || true)
}

# Function to check for localhost/IP without env var fallback
scan_localhost_ips() {
  local file="$1"
  
  # Skip binary files
  if ! file "$file" 2>/dev/null | grep -q "text"; then
    return 0
  fi
  
  # Look for localhost or IP addresses that aren't in ${VAR:-} patterns
  while IFS=: read -r line_num line_content; do
    # Skip if line contains ${VAR:-localhost} pattern (bash/sh fallback)
    if echo "$line_content" | grep -qE '\$\{[^}]+:-[^}]*(localhost|127\.0\.0\.1)'; then
      continue
    fi
    
    # Skip if line contains || 'localhost' pattern (JS/TS fallback)
    if echo "$line_content" | grep -qE '\|\|\s*["\047](https?://)?(localhost|127\.0\.0\.1)'; then
      continue
    fi
    
    # Skip if it's process.env with fallback
    if echo "$line_content" | grep -qE 'process\.env\.[A-Z_]+\s*\|\|'; then
      continue
    fi
    
    # Skip comments
    if echo "$line_content" | grep -qE '^\s*(#|//|/\*|\*)'; then
      continue
    fi
    
    if [ -n "$line_num" ]; then
			echo -e "${YELLOW}[BLOCKED] localhost/IP without env var fallback${NC}" >&2
			echo "  File: $file" >&2
			echo "  Line $line_num: $line_content" >&2
			echo "  Use: \${VAR:-localhost:port} or process.env.VAR || 'http://localhost:port'" >&2
			echo "" >&2
			SECRETS_FOUND=1
    fi
  done < <(grep -nE '(localhost|127\.0\.0\.1|0\.0\.0\.0|192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+' "$file" 2>/dev/null | \
           grep -vE '\$\{[^}]+:-' | \
           grep -vE '\|\|' || true)
}

# Main scanning loop
for file in $STAGED_FILES; do
  # Check if file exists (might be deleted)
  if [ ! -f "$file" ]; then
    continue
  fi
  
  scan_secrets "$file"
  scan_hardcoded_urls "$file"
  scan_localhost_ips "$file"
done

# Report results
if [ "$SECRETS_FOUND" -eq 1 ]; then
	jq -n --arg r "BLOCKED: Secrets or hardcoded values detected in staged files. Remove secrets, use env vars, then retry commit." \
		'{permissionDecision: "deny", permissionDecisionReason: $r}'
	exit 0
fi

exit 0
