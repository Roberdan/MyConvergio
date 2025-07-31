#!/bin/bash

# =============================================================================
# MYCONVERGIO AGENT TRANSLATION SCRIPT
# =============================================================================
# This script helps translate agent files from English to Italian
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_AGENTS_DIR="$ROOT_DIR/claude-agents"
TARGET_AGENTS_DIR="$ROOT_DIR/claude-agenti"

# Create target directories if they don't exist
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"
    find "$SRC_AGENTS_DIR" -type d | while read -r dir; do
        rel_path="${dir#$SRC_AGENTS_DIR}"
        mkdir -p "${TARGET_AGENTS_DIR}${rel_path}"
    done
}

# Translate a single file
translate_file() {
    local src_file="$1"
    local rel_path="${src_file#$SRC_AGENTS_DIR}"
    local target_file="${TARGET_AGENTS_DIR}${rel_path}"
    
    echo -e "${BLUE}Translating: $rel_path${NC}"
    
    # Copy the file first
    cp "$src_file" "$target_file"
    
    # Add translation notice
    sed -i '' '1i\
<!-- 
  TRADUZIONE IN ITALIANO - ITALIAN TRANSLATION
  Questo file è una traduzione automatica. Per favore verifica e adatta la traduzione secondo necessità.
  This is an automatic translation. Please verify and adapt the translation as needed.
-->' "$target_file"
    
    # Translate common patterns (this is a simplified example)
    sed -i '' 's/description: "/description: "[IT] /g' "$target_file"
    sed -i '' 's/You are \([A-Za-z-]*\), the/Sei \1, il/gi' "$target_file"
    # Add more translation patterns as needed
    
    echo -e "${GREEN}Translated: $rel_path${NC}"
}

# Main function
main() {
    echo -e "${BLUE}Starting agent translation from English to Italian...${NC}"
    
    # Create directory structure
    create_directories
    
    # Count total files to translate
    total_files=$(find "$SRC_AGENTS_DIR" -type f -name "*.md" | wc -l)
    current=0
    
    # Process each file
    find "$SRC_AGENTS_DIR" -type f -name "*.md" | while read -r file; do
        current=$((current + 1))
        echo -e "\n${BLUE}[$current/$total_files]${NC}"
        translate_file "$file"
    done
    
    echo -e "\n${GREEN}Translation complete!${NC}"
    echo -e "Files have been translated to: $TARGET_AGENTS_DIR"
    echo -e "${YELLOW}Please review the translations and make any necessary adjustments.${NC}"
}

# Run the script
main "$@"
