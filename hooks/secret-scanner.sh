#!/bin/bash
# secret-scanner.sh: Pre-commit hook for secret detection
# Scans staged files for API keys, tokens, hardcoded URLs, and localhost/IPs
# Exit 1 = BLOCK commit, Exit 0 = ALLOW
# Version: 1.0.0

set -euo pipefail

# Dry-run mode: warn instead of block
if [[ "${MYCONVERGIO_DRY_RUN:-0}" == "1" ]]; then
	DRY_RUN=true
else
	DRY_RUN=false
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
  # No staged files, allow commit
  exit 0
fi

echo "🔍 Scanning staged files for secrets..."
echo ""

# Function to report secret found
report_secret() {
  local file="$1"
  local line_num="$2"
  local pattern_name="$3"
  local line_content="$4"
  
  echo -e "${RED}[BLOCKED] Secret detected: $pattern_name${NC}"
  echo "  File: $file"
  echo "  Line $line_num: $line_content"
  echo ""
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
      echo -e "${RED}[BLOCKED] Hardcoded URL detected${NC}"
      echo "  File: $file"
      echo "  Line $line_num: $line_content"
      echo "  Use environment variables instead: process.env.API_URL or \${API_URL}"
      echo ""
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
      echo -e "${YELLOW}[BLOCKED] localhost/IP without env var fallback${NC}"
      echo "  File: $file"
      echo "  Line $line_num: $line_content"
      echo "  Use: \${VAR:-localhost:port} or process.env.VAR || 'http://localhost:port'"
      echo ""
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
if [ $SECRETS_FOUND -eq 1 ]; then
  if $DRY_RUN; then
    echo -e "${YELLOW}⚠ DRY-RUN: Secrets detected but not blocking${NC}"
    exit 0
  fi
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ COMMIT BLOCKED: Secrets or hardcoded values detected${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Actions to fix:"
  echo "  1. Remove secrets and use environment variables"
  echo "  2. Use .env files (ensure .env is in .gitignore)"
  echo "  3. Add env var fallbacks for localhost/IPs"
  echo "  4. Review and unstage: git reset HEAD <file>"
  echo ""
  exit 1
else
  echo "✅ No secrets detected. Commit allowed."
  exit 0
fi
