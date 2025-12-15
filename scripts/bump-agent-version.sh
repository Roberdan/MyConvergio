#!/bin/bash

# =============================================================================
# AGENT VERSION BUMP SCRIPT
# =============================================================================
# Bumps version for specific agent or all agents
# Updates both frontmatter and changelog
# Part of WAVE 5 Agent Optimization Plan 2025
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="$ROOT_DIR/.claude/agents"

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Function to extract current version from frontmatter
get_current_version() {
    local file="$1"
    grep '^version:' "$file" | sed 's/version: "\(.*\)"/\1/' | tr -d '"'
}

# Function to bump version
bump_version() {
    local version="$1"
    local bump_type="$2"

    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            echo "$version"
            ;;
    esac
}

# Function to update version in file
update_agent_version() {
    local file="$1"
    local new_version="$2"
    local change_description="$3"

    local agent_name=$(basename "$file" .md)
    local current_version=$(get_current_version "$file")

    if [ -z "$current_version" ]; then
        echo -e "${RED}Error: Could not find version in $agent_name${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}Updating $agent_name: $current_version → $new_version${NC}"

    # Update version in frontmatter
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: \".*\"/version: \"$new_version\"/" "$file"
    else
        # Linux
        sed -i "s/^version: \".*\"/version: \"$new_version\"/" "$file"
    fi

    # Add changelog entry
    local changelog_entry="- **$new_version** ($CURRENT_DATE): $change_description"

    # Find the changelog section and add the new entry after "## Changelog"
    if grep -q "^## Changelog" "$file"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "/^## Changelog/a\\
$changelog_entry
" "$file"
        else
            # Linux
            sed -i "/^## Changelog/a $changelog_entry" "$file"
        fi
    else
        echo -e "${YELLOW}Warning: No changelog section found in $agent_name${NC}"
    fi

    echo -e "${GREEN}✓ Updated $agent_name${NC}"
}

# Show help
show_help() {
    echo -e "${BLUE}MyConvergio Agent Version Bump${NC}"
    echo "Usage: $0 [options] <bump_type> [agent_name] [change_description]"
    echo ""
    echo "Bump Types:"
    echo "  major         Bump major version (X.0.0)"
    echo "  minor         Bump minor version (0.X.0)"
    echo "  patch         Bump patch version (0.0.X)"
    echo ""
    echo "Options:"
    echo "  --all         Bump all agents"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 patch ali-chief-of-staff 'Fixed bug in orchestration'"
    echo "  $0 minor baccio-tech-architect 'Added new architecture patterns'"
    echo "  $0 --all patch 'Security framework updates'"
    echo ""
}

# Main function
main() {
    local bump_all=false
    local bump_type=""
    local agent_name=""
    local change_description=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                bump_all=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            major|minor|patch)
                bump_type="$1"
                shift
                ;;
            *)
                if [ -z "$agent_name" ]; then
                    agent_name="$1"
                elif [ -z "$change_description" ]; then
                    change_description="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate arguments
    if [ -z "$bump_type" ]; then
        echo -e "${RED}Error: Bump type required (major|minor|patch)${NC}" >&2
        show_help
        exit 1
    fi

    if [ -z "$change_description" ]; then
        echo -e "${RED}Error: Change description required${NC}" >&2
        show_help
        exit 1
    fi

    if [ "$bump_all" = true ]; then
        echo -e "${BLUE}Bumping all agents ($bump_type)...${NC}"
        echo ""

        local count=0
        find "$AGENTS_DIR" -type f -name "*.md" \
            ! -name "CONSTITUTION.md" \
            ! -name "MICROSOFT_VALUES.md" \
            ! -name "CommonValuesAndPrinciples.md" \
            ! -name "SECURITY_FRAMEWORK_TEMPLATE.md" | while read -r file; do

            local current_version=$(get_current_version "$file")
            local new_version=$(bump_version "$current_version" "$bump_type")
            update_agent_version "$file" "$new_version" "$change_description"
            count=$((count + 1))
        done

        echo ""
        echo -e "${GREEN}✨ All agents updated!${NC}"
    else
        if [ -z "$agent_name" ]; then
            echo -e "${RED}Error: Agent name required${NC}" >&2
            show_help
            exit 1
        fi

        # Find the agent file
        local agent_file=$(find "$AGENTS_DIR" -type f -name "$agent_name.md" | head -1)

        if [ -z "$agent_file" ]; then
            echo -e "${RED}Error: Agent '$agent_name' not found${NC}" >&2
            exit 1
        fi

        local current_version=$(get_current_version "$agent_file")
        local new_version=$(bump_version "$current_version" "$bump_type")
        update_agent_version "$agent_file" "$new_version" "$change_description"

        echo ""
        echo -e "${GREEN}✨ Version bumped successfully!${NC}"
    fi
}

# Run the script
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

main "$@"
