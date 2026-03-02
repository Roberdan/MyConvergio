#!/bin/bash
# Dashboard configuration — paths, colors, constants
# Version: 2.0.0

# Base colors (ANSI)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Paths
DB="${DB:-$HOME/.claude/data/dashboard.db}"
SYNC_SCRIPT="$HOME/.claude/scripts/sync-dashboard-db.sh"
REMOTE_GIT_CACHE="$HOME/.claude/data/remote-git-cache.json"
DASHBOARD_LIB="${DASHBOARD_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
