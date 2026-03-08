#!/bin/bash
# Shared color definitions for claude scripts
# Version: 1.0.0

# Disable colors if not a terminal
if [[ -t 1 ]]; then
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[1;33m'
	BLUE='\033[0;34m'
	CYAN='\033[0;36m'
	BOLD='\033[1m'
	NC='\033[0m'
else
	RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi
