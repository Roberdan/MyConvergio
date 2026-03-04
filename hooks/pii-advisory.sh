#!/usr/bin/env bash
# pii-advisory.sh — postToolUse hook (ADVISORY-ONLY)
# Scans bash/shell output for PII. Logs findings, never blocks/modifies.
# Version: 1.0.0

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // .tool_name // ""' 2>/dev/null)

# Only scan bash/shell output
if [[ "$TOOL_NAME" != "bash" && "$TOOL_NAME" != "shell" && "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

OUTPUT=$(echo "$INPUT" | jq -r '.toolOutput // .tool_output // .stdout // ""' 2>/dev/null)
[[ -z "$OUTPUT" ]] && exit 0

# Counters
EMAIL_COUNT=0
PHONE_COUNT=0
KEY_COUNT=0

# --- WHITELIST PATTERNS (skip these) ---
# RFC1918 private ranges, loopback, link-local
WHITELIST_IP='(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|127\.[0-9]+\.[0-9]+\.[0-9]+|0\.0\.0\.0|::1|localhost)'

# --- DETECT PATTERNS ---

# Emails (basic: user@domain.tld, skip @users.noreply.github.com)
EMAIL_MATCHES=$(echo "$OUTPUT" | grep -oEi '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | grep -v 'noreply.github.com' | grep -v 'example\.com' || true)
if [[ -n "$EMAIL_MATCHES" ]]; then
    EMAIL_COUNT=$(echo "$EMAIL_MATCHES" | wc -l | tr -d ' ')
fi

# API Keys (sk-*, ghp_*, AKIA*, xox-*, glpat-*)
KEY_MATCHES=$(echo "$OUTPUT" | grep -oE '(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36,}|AKIA[A-Z0-9]{16}|xox[bpras]-[a-zA-Z0-9-]+|glpat-[a-zA-Z0-9_-]{20,})' || true)
if [[ -n "$KEY_MATCHES" ]]; then
    KEY_COUNT=$(echo "$KEY_MATCHES" | wc -l | tr -d ' ')
fi

# Phone numbers (international format: +xx xxx... , min 10 digits)
PHONE_MATCHES=$(echo "$OUTPUT" | grep -oE '\+[0-9]{1,3}[ -]?[0-9]{6,14}' || true)
if [[ -n "$PHONE_MATCHES" ]]; then
    PHONE_COUNT=$(echo "$PHONE_MATCHES" | wc -l | tr -d ' ')
fi

TOTAL=$((EMAIL_COUNT + PHONE_COUNT + KEY_COUNT))

# Log if any PII found
if [[ $TOTAL -gt 0 ]]; then
    LOG_DIR="$HOME/.claude/logs"
    mkdir -p "$LOG_DIR"
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] PII advisory: ${EMAIL_COUNT} emails, ${KEY_COUNT} keys, ${PHONE_COUNT} phones (tool: $TOOL_NAME)" >> "$LOG_DIR/pii-advisory.log"
fi

# Always allow — advisory only
exit 0
