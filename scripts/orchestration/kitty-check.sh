#!/bin/bash
# Verify Kitty is properly configured for Claude orchestration
#
# REQUIRES: Kitty terminal
# See: scripts/orchestration/README.md

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[✓]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo "Kitty Orchestration Setup Check"
echo "================================"
echo ""

# Check if running in Kitty
if [ -n "$KITTY_PID" ]; then
    pass "Running inside Kitty (PID: $KITTY_PID)"
else
    fail "Not running inside Kitty"
    echo "    → Open Kitty and run this check again"
fi

# Check kitty config
CONFIG="$HOME/.config/kitty/kitty.conf"
if [ -f "$CONFIG" ]; then
    if grep -q "^allow_remote_control yes" "$CONFIG" 2>/dev/null; then
        pass "Remote control enabled"
    elif grep -q "allow_remote_control" "$CONFIG" 2>/dev/null; then
        warn "Remote control configured but may not be 'yes'"
        echo "    → Check: grep allow_remote_control $CONFIG"
    else
        fail "Remote control not configured"
        echo "    → Add to $CONFIG:"
        echo "      allow_remote_control yes"
    fi

    if grep -q "^listen_on" "$CONFIG" 2>/dev/null; then
        pass "Listen socket configured"
    else
        warn "Listen socket not explicitly set (using default)"
        echo "    → Optionally add: listen_on unix:/tmp/kitty-socket"
    fi
else
    fail "Kitty config not found at $CONFIG"
    echo "    → Create the file and add:"
    echo "      allow_remote_control yes"
fi

# Check kitty @ connectivity
if kitty @ ls &>/dev/null; then
    pass "Remote control connection works"
    TABS=$(kitty @ ls 2>/dev/null | grep -c '"title"' || echo "0")
    echo "    → Current tabs: $TABS"
else
    fail "Cannot connect to Kitty remote control"
    echo "    → Restart Kitty after enabling remote control"
fi

# Check wildClaude
if alias wildClaude &>/dev/null 2>&1 || command -v wildClaude &>/dev/null 2>&1; then
    pass "wildClaude alias available"
else
    warn "wildClaude alias not found"
    echo "    → Add to ~/.zshrc:"
    echo "      alias wildClaude='claude --dangerously-skip-permissions'"
fi

# Check claude
if command -v claude &>/dev/null; then
    pass "Claude CLI installed"
    VERSION=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    echo "    → Version: $VERSION"
else
    fail "Claude CLI not found"
fi

echo ""
echo "================================"
if [ -n "$KITTY_PID" ] && kitty @ ls &>/dev/null; then
    echo -e "${GREEN}Ready for orchestration!${NC}"
    echo ""
    echo "Usage:"
    echo "  ./scripts/orchestration/claude-parallel.sh 4"
    echo "  ./scripts/orchestration/claude-monitor.sh"
else
    echo -e "${RED}Setup incomplete - fix issues above${NC}"
fi
echo ""
