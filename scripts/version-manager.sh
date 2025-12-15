#!/bin/bash

# =============================================================================
# MYCONVERGIO VERSION MANAGER
# =============================================================================
# Handles version management for both the MyConvergio system and individual agents
# Version: 1.0.0
# =============================================================================

# Enable error handling and debugging
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$ROOT_DIR/VERSION"
AGENTS_DIR="$ROOT_DIR/.claude/agents"

# Load version file
load_version_file() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo -e "${RED}Error: Version file not found at $VERSION_FILE${NC}" >&2
        exit 1
    fi
    
    # Source the version file to get the system version
    SYSTEM_VERSION=$(grep '^SYSTEM_VERSION=' "$VERSION_FILE" | cut -d'=' -f2-)
    if [ -z "$SYSTEM_VERSION" ]; then
        echo -e "${RED}Error: Could not determine system version${NC}" >&2
        exit 1
    fi
}

# Get current system version
get_system_version() {
    load_version_file
    echo "$SYSTEM_VERSION"
}

# Get version for a specific agent
get_agent_version() {
    local agent_name="$1"
    local version_line=$(grep -i "^$agent_name=" "$VERSION_FILE" 2>/dev/null || true)
    
    if [ -n "$version_line" ]; then
        echo "$version_line" | cut -d' ' -f1 | cut -d'=' -f2
    else
        echo "0.0.0"
    fi
}

# Update system version
update_system_version() {
    local new_version="$1"
    
    # Validate version format (semver)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.]+)?$ ]]; then
        echo -e "${RED}Error: Invalid version format. Use MAJOR.MINOR.PATCH[-PRERELEASE]${NC}" >&2
        return 1
    fi
    
    # Update version in VERSION file
    sed -i '' "s/^SYSTEM_VERSION=.*/SYSTEM_VERSION=$new_version/" "$VERSION_FILE"
    
    echo -e "${GREEN}System version updated to $new_version${NC}"
}

# Update agent version
update_agent_version() {
    local agent_name="$1"
    local new_version="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Validate version format (semver)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.]+)?$ ]]; then
        echo -e "${RED}Error: Invalid version format. Use MAJOR.MINOR.PATCH[-PRERELEASE]${NC}" >&2
        return 1
    fi
    
    # Remove existing version if it exists
    sed -i '' "/^$agent_name=/d" "$VERSION_FILE" 2>/dev/null || true
    
    # Add new version
    echo "$agent_name=$new_version $timestamp" >> "$VERSION_FILE"
    
    echo -e "${GREEN}Agent '$agent_name' version updated to $new_version${NC}"
}

# Scan agents directory and update versions
scan_agents() {
    echo -e "${BLUE}Scanning for agents in $AGENTS_DIR...${NC}"
    
    # Create a temporary file for the new version file
    local temp_file=$(mktemp)
    
    # Keep the system version header
    grep -E '^#|^$|^SYSTEM_VERSION=' "$VERSION_FILE" > "$temp_file"
    
    # Find all agent files and process them
    find "$AGENTS_DIR" -type f -name "*.md" | while read -r agent_file; do
        local agent_name=$(basename "$agent_file" .md)
        local current_version=$(get_agent_version "$agent_name")
        
        # If agent not in version file, add it with version 0.1.0
        if [ "$current_version" = "0.0.0" ]; then
            echo -e "${YELLOW}New agent detected: $agent_name (setting to v0.1.0)${NC}"
            echo "$agent_name=0.1.0 $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$temp_file"
        else
            # Keep existing version
            grep "^$agent_name=" "$VERSION_FILE" 2>/dev/null || true >> "$temp_file"
        fi
    done
    
    # Replace the version file
    mv "$temp_file" "$VERSION_FILE"
    
    echo -e "${GREEN}Agent versions updated successfully${NC}"
}

# List all agents and their versions
list_agents() {
    load_version_file
    
    echo -e "${BLUE}MyConvergio System Version: $SYSTEM_VERSION${NC}"
    echo -e "${BLUE}Agent versions:${NC}"
    echo "--------------------------------------------------"
    
    # List all agents with versions
    grep -v '^#' "$VERSION_FILE" | grep '=' | while read -r line; do
        if [[ "$line" == SYSTEM_VERSION=* ]]; then
            continue
        fi
        
        local agent_name=$(echo "$line" | cut -d'=' -f1)
        local version_info=$(echo "$line" | cut -d' ' -f1 | cut -d'=' -f2)
        local timestamp=$(echo "$line" | cut -d' ' -f2-)
        
        printf "%-30s %-15s %s\n" "$agent_name" "v$version_info" "$timestamp"
    done | sort
}

# Show help
show_help() {
    echo -e "${BLUE}MyConvergio Version Manager${NC}"
    echo "Usage: $0 [command] [args...]"
    echo ""
    echo "Commands:"
    echo "  list                     List all agents and their versions"
    echo "  scan                     Scan for new agents and update versions"
    echo "  system-version           Show current system version"
    echo "  system-version <version>  Update system version"
    echo "  agent-version <name>     Show version for a specific agent"
    echo "  agent-version <name> <version>  Update version for a specific agent"
    echo "  help                     Show this help message"
}

# Main command handler
main() {
    case "$1" in
        list)
            list_agents
            ;;
        scan)
            scan_agents
            ;;
        system-version)
            if [ -n "${2:-}" ]; then
                update_system_version "$2"
            else
                get_system_version
            fi
            ;;
        agent-version)
            if [ -z "${2:-}" ]; then
                echo -e "${RED}Error: Agent name is required${NC}" >&2
                exit 1
            fi
            if [ -n "${3:-}" ]; then
                update_agent_version "$2" "$3"
            else
                get_agent_version "$2"
            fi
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$1'${NC}" >&2
            show_help
            exit 1
            ;;
    esac
}

# Run the script
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

main "$@"
