#!/bin/bash
# secrets-scan.sh — Detect leaked secrets in staged files
# Scans staged git files for common secret patterns.
# Exit 1 = secrets found (BLOCKS commit). Exit 0 = clean.
# ADAPT: Add project-specific patterns to PATTERNS array
set -euo pipefail

STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

# Skip binary and lock files
STAGED=$(echo "$STAGED" | grep -vE '\.(png|jpg|gif|ico|woff|ttf|eot|lock|sum)$' || true)
[ -z "$STAGED" ] && exit 0

# ADAPT: Add/remove patterns for your project
PATTERNS=(
	# Generic API keys
	'["\x27]sk-[a-zA-Z0-9]{20,}["\x27]'
	'["\x27]pk-[a-zA-Z0-9]{20,}["\x27]'
	# AWS
	'AKIA[0-9A-Z]{16}'
	'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}'
	# Private keys
	'-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
	# Generic password assignments
	'(password|passwd|secret|token)\s*[:=]\s*["\x27][^\s"]{8,}["\x27]'
	# Azure connection strings
	'AccountKey=[A-Za-z0-9+/=]{40,}'
	# JWT tokens
	'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'
	# Database URLs with credentials
	'(postgres|mysql|mongodb)://[^:]+:[^@]+@'
)

FOUND=0
for pattern in "${PATTERNS[@]}"; do
	# shellcheck disable=SC2086
	MATCHES=$(echo "$STAGED" | xargs grep -lnE "$pattern" 2>/dev/null || true)
	if [ -n "$MATCHES" ]; then
		[ $FOUND -eq 0 ] && echo "[secrets-scan] POTENTIAL SECRETS DETECTED:"
		echo "  Pattern: $pattern"
		echo "$MATCHES" | while read -r f; do echo "    - $f"; done
		FOUND=1
	fi
done

[ $FOUND -ne 0 ] && echo "[secrets-scan] Remove secrets before committing!" && exit 1
echo "[secrets-scan] Clean — no secrets detected"
