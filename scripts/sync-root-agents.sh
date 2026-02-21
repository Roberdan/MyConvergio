#!/usr/bin/env bash
# =============================================================================
# sync-root-agents.sh - Synchronize root agents/ from .claude/agents/
# =============================================================================
# Version: 1.0.0
# Description: Syncs agent files from .claude/agents/ (source of truth) to 
#              root agents/ directory. Generates corresponding files with 
#              frontmatter and content preserved.
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Directories
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE_DIR="${REPO_ROOT}/.claude/agents"
readonly TARGET_DIR="${REPO_ROOT}/agents"

# Counters
ADDED=0
UPDATED=0
REMOVED=0
SKIPPED=0

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Check if directory exists
check_directories() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
        log_warning "Target directory not found, creating: $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi
}

# Extract basename without extension
get_basename() {
    local file="$1"
    basename "$file" .md
}

# Check if file content differs
files_differ() {
    local source="$1"
    local target="$2"
    
    if [[ ! -f "$target" ]]; then
        return 0  # Target doesn't exist, so they differ
    fi
    
    # Compare file contents
    if ! diff -q "$source" "$target" >/dev/null 2>&1; then
        return 0  # Files differ
    fi
    
    return 1  # Files are the same
}

# Sync a single agent file
sync_agent_file() {
    local source_file="$1"
    local relative_path="${source_file#$SOURCE_DIR/}"
    local target_file="${TARGET_DIR}/${relative_path}"
    local target_dir="$(dirname "$target_file")"
    
    # Skip non-.md files and special directories
    if [[ ! "$source_file" =~ \.md$ ]]; then
        return
    fi
    
    # Skip config, scripts, templates subdirectories
    if [[ "$relative_path" =~ (config|scripts|templates)/ ]]; then
        SKIPPED=$((SKIPPED + 1))
        return
    fi
    
    # Create target directory if needed
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi
    
    # Check if file needs updating
    if files_differ "$source_file" "$target_file"; then
        if [[ -f "$target_file" ]]; then
            log_info "Updating: $relative_path"
            cp "$source_file" "$target_file"
            UPDATED=$((UPDATED + 1))
        else
            log_success "Adding: $relative_path"
            cp "$source_file" "$target_file"
            ADDED=$((ADDED + 1))
        fi
    fi
}

# Remove orphaned files in target that don't exist in source
remove_orphaned_files() {
    log_info "Checking for orphaned files..."
    
    # Find all .md files in target
    while IFS= read -r -d '' target_file; do
        local relative_path="${target_file#$TARGET_DIR/}"
        local source_file="${SOURCE_DIR}/${relative_path}"
        
        # Skip if corresponding source exists
        if [[ -f "$source_file" ]]; then
            continue
        fi
        
        # Remove orphaned file
        log_warning "Removing orphaned: $relative_path"
        rm -f "$target_file"
        REMOVED=$((REMOVED + 1))
    done < <(find "$TARGET_DIR" -type f -name "*.md" -print0 2>/dev/null || true)
    
    # Remove empty directories
    find "$TARGET_DIR" -type d -empty -delete 2>/dev/null || true
}

# Sync all agent files
sync_all_agents() {
    log_info "Syncing agents from .claude/agents/ to agents/..."
    echo ""
    
    # Find and sync all .md files from source
    while IFS= read -r -d '' source_file; do
        sync_agent_file "$source_file"
    done < <(find "$SOURCE_DIR" -type f -name "*.md" -print0 2>/dev/null || true)
    
    # Remove orphaned files
    remove_orphaned_files
}

# Print summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Sync Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ $ADDED -gt 0 ]; then
        echo -e "  ${GREEN}Added:${NC}    $ADDED files"
    fi
    
    if [ $UPDATED -gt 0 ]; then
        echo -e "  ${BLUE}Updated:${NC}  $UPDATED files"
    fi
    
    if [ $REMOVED -gt 0 ]; then
        echo -e "  ${YELLOW}Removed:${NC}  $REMOVED files"
    fi
    
    if [ $SKIPPED -gt 0 ]; then
        echo -e "  ${NC}Skipped:${NC}  $SKIPPED files (config/scripts/templates)"
    fi
    
    local total=$((ADDED + UPDATED + REMOVED))
    if [ $total -eq 0 ]; then
        echo -e "  ${GREEN}No changes needed - all files in sync${NC}"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "MyConvergio Agent Sync Utility v1.0.0"
    echo ""
    
    check_directories
    sync_all_agents
    print_summary
    
    # Exit with appropriate code
    if [ $REMOVED -gt 0 ]; then
        exit 0  # Removed files is OK
    fi
    
    exit 0
}

# Run main function
main "$@"
