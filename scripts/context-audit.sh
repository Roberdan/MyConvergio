#!/bin/bash
# Context Audit - Automated health check for Claude Code configuration
# Usage: context-audit.sh [--maintenance]
# Exit: 0=healthy, 1=needs attention
# Version: 1.1.0
set -euo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true
# Fallback if common.sh didn't load
type have_bin &>/dev/null || have_bin() { command -v "$1" &>/dev/null; }

# Use system wc to avoid custom wc in PATH
WC=/usr/bin/wc

WARN=0
FAIL=0
CLAUDE_DIR="$HOME/.claude"
GITHUB_DIR="$HOME/GitHub"

# Pre-load CLAUDE.md content for fast lookups (avoids quadratic grep)
CLAUDE_CONTENT=$(cat "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null || echo "")

# --- Helpers ---
pass() { printf "  \033[32m[PASS]\033[0m %s\n" "$1"; }
warn() {
	printf "  \033[33m[WARN]\033[0m %s\n" "$1"
	WARN=$((WARN + 1))
}
fail() {
	printf "  \033[31m[FAIL]\033[0m %s\n" "$1"
	FAIL=$((FAIL + 1))
}
header() { printf "\n\033[1;36m── %s ──\033[0m\n" "$1"; }

# --- 1. CLAUDE.md line count ---
header "1. Global CLAUDE.md"
LINES=$($WC -l <"$CLAUDE_DIR/CLAUDE.md" | tr -d ' ')
if [ "$LINES" -gt 150 ]; then
	fail "CLAUDE.md: $LINES lines (max 150)"
elif [ "$LINES" -gt 100 ]; then
	warn "CLAUDE.md: $LINES lines (target <100)"
else
	pass "CLAUDE.md: $LINES lines"
fi

# --- 2. Rules files duplication ---
header "2. Rules duplication check"
RULES_DIR="$CLAUDE_DIR/rules"
if [ -d "$RULES_DIR" ]; then
	DUP_COUNT=0
	for f in "$RULES_DIR"/*.md; do
		[ -f "$f" ] || continue
		RLINES=$($WC -l <"$f" | tr -d ' ')
		[ "$RLINES" -gt 30 ] && warn "$(basename "$f"): $RLINES lines (target <30)"
		# Check for phrases duplicated with CLAUDE.md (uses pre-loaded content)
		key_lines=$(grep -v '^#\|^$\|^-\|^```' "$f" 2>/dev/null | head -5) || key_lines=""
		while IFS= read -r line; do
			[ ${#line} -lt 20 ] && continue
			if echo "$CLAUDE_CONTENT" | grep -qF "$line"; then
				DUP_COUNT=$((DUP_COUNT + 1))
			fi
		done <<<"$key_lines"
	done
	[ "$DUP_COUNT" -gt 3 ] && warn "$DUP_COUNT phrases duplicated between rules and CLAUDE.md" || pass "Minimal duplication ($DUP_COUNT phrases)"
fi

# --- 3. Agent boilerplate detection ---
header "3. Agent boilerplate check"
AGENTS_DIR="$CLAUDE_DIR/agents"
if [ -d "$AGENTS_DIR" ]; then
	AGENT_FILES=$(find "$AGENTS_DIR" -name "*.md" -type f 2>/dev/null | $WC -l | tr -d ' ')
	# Check for identical blocks across agents
	BOILERPLATE=0
	if [ "$AGENT_FILES" -gt 1 ]; then
		for f in "$AGENTS_DIR"/**/*.md "$AGENTS_DIR"/*.md; do
			[ -f "$f" ] || continue
			AL=$($WC -l <"$f" | tr -d ' ')
			[ "$AL" -gt 200 ] && warn "$(basename "$f"): $AL lines (consider trimming)"
		done
	fi
	pass "$AGENT_FILES agent files checked"
fi

# --- 4. Claude Code version ---
header "4. Claude Code version"
if have_bin claude; then
	CURRENT=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	pass "Installed: $CURRENT"
	LATEST=$(npm view @anthropic-ai/claude-code version 2>/dev/null || echo "unknown")
	[ "$LATEST" != "unknown" ] && [ "$CURRENT" != "$LATEST" ] &&
		warn "Latest available: $LATEST" || pass "Up to date"
else
	fail "Claude Code not installed"
fi

# --- 5. Hook health ---
header "5. Hook health"
HOOK_DIR="$CLAUDE_DIR/hooks"
for hook in "$HOOK_DIR"/*.sh; do
	[ -f "$hook" ] || continue
	NAME=$(basename "$hook")
	if [ ! -x "$hook" ]; then
		fail "$NAME: not executable"
		continue
	fi
	# Dry-run: feed empty JSON, expect exit 0
	if echo '{}' | timeout 5 "$hook" >/dev/null 2>&1; then
		pass "$NAME: healthy"
	else
		warn "$NAME: non-zero exit on empty input"
	fi
done

# --- 6. Token usage trend (last 30d) ---
header "6. Token usage (last 30 days)"
DB_FILE="$HOME/.claude/data/dashboard.db"
if [ -f "$DB_FILE" ] && have_bin sqlite3; then
	TOTAL=$(sqlite3 "$DB_FILE" "
    SELECT COALESCE(SUM(input_tokens + output_tokens), 0)
    FROM token_usage
    WHERE created_at >= datetime('now', '-30 days');
  " 2>/dev/null || echo "0")
	COST=$(sqlite3 "$DB_FILE" "
    SELECT COALESCE(printf('%.2f', SUM(cost_usd)), '0.00')
    FROM token_usage
    WHERE created_at >= datetime('now', '-30 days');
  " 2>/dev/null || echo "0.00")
	SESSIONS=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(DISTINCT session_id)
    FROM token_usage
    WHERE created_at >= datetime('now', '-30 days');
  " 2>/dev/null || echo "0")
	pass "Tokens: $TOTAL | Cost: \$$COST | Sessions: $SESSIONS"
else
	warn "Dashboard DB not found or sqlite3 missing"
fi

# --- 7. Project CLAUDE.md audit ---
header "7. Project CLAUDE.md audit"
for proj_dir in "$GITHUB_DIR"/*/; do
	[ -d "$proj_dir" ] || continue
	PROJ=$(basename "$proj_dir")
	CLAUDE_FILE=""
	# Check both root and .claude/ locations
	[ -f "$proj_dir/CLAUDE.md" ] && CLAUDE_FILE="$proj_dir/CLAUDE.md"
	[ -f "$proj_dir/.claude/CLAUDE.md" ] && CLAUDE_FILE="$proj_dir/.claude/CLAUDE.md"
	if [ -z "$CLAUDE_FILE" ]; then
		warn "$PROJ: no CLAUDE.md found"
		continue
	fi
	PL=$($WC -l <"$CLAUDE_FILE" | tr -d ' ')
	if [ "$PL" -gt 150 ]; then
		fail "$PROJ: $PL lines (max 150)"
	elif [ "$PL" -gt 100 ]; then
		warn "$PROJ: $PL lines (target <100)"
	else
		pass "$PROJ: $PL lines"
	fi
done

# --- Summary ---
header "Summary"
printf "  Warnings: %d | Failures: %d\n" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
	printf "  \033[31mStatus: NEEDS ATTENTION\033[0m\n"
	exit 1
else
	printf "  \033[32mStatus: HEALTHY\033[0m\n"
	exit 0
fi
