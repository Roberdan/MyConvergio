#!/usr/bin/env bash
# Auto-generate copilot-agents/*.agent.md from .claude/agents/*.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/.claude/agents"
TARGET_DIR="$REPO_ROOT/copilot-agents"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Model name mapping
declare -A MODEL_MAP=(
  ["sonnet"]="claude-sonnet-4.5" ["opus"]="claude-opus-4.6" ["opus-1m"]="claude-opus-4.6-1m"
  ["haiku"]="claude-haiku-4.5" ["codex"]="gpt-5.3-codex" ["codex-mini"]="gpt-5.1-codex-mini"
  ["claude-sonnet-4.5"]="claude-sonnet-4.5" ["claude-opus-4.6"]="claude-opus-4.6"
  ["claude-opus-4.6-1m"]="claude-opus-4.6-1m" ["claude-haiku-4.5"]="claude-haiku-4.5"
  ["gpt-5.3-codex"]="gpt-5.3-codex" ["gpt-5.1-codex-mini"]="gpt-5.1-codex-mini"
)

CONVERTED=0 SKIPPED=0 ERRORS=0

show_usage() {
  cat <<EOF
Usage: $(basename "$0") [-h|--help] [-v|--verbose] [--dry-run]

Auto-generate copilot-agents/*.agent.md from .claude/agents/*.md
Converts frontmatter, normalizes tools, maps models, removes Claude-specific fields.
EOF
}

VERBOSE=false DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_usage; exit 0 ;;
    -v|--verbose) VERBOSE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

# Convert model name using mapping
map_model_name() {
  local model="$1"
  # Remove quotes if present
  model="${model#\"}"
  model="${model%\"}"
  # Remove any leading/trailing whitespace
  model=$(echo "$model" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  if [[ -n "${MODEL_MAP[$model]:-}" ]]; then
    echo "${MODEL_MAP[$model]}"
  else
    # If no mapping found, return original
    echo "$model"
  fi
}

# Normalize tool names to lowercase
normalize_tools() {
  local tools_line="$1"
  # Convert to lowercase, handle both ["Read", "Write"] and ["read", "write"] formats
  echo "$tools_line" | sed 's/"Read"/"read"/g; s/"Write"/"write"/g; s/"Edit"/"edit"/g; s/"Bash"/"execute"/g; s/"Execute"/"execute"/g; s/"Glob"/"search"/g; s/"Grep"/"search"/g; s/"Search"/"search"/g; s/"Task"/"task"/g'
}

# Extract and convert frontmatter
convert_frontmatter() {
  local input_file="$1"
  local in_frontmatter=false
  local frontmatter=""
  local content=""
  local after_frontmatter=false
  local line_num=0
  local in_handoffs=false
  
  while IFS= read -r -u 3 line; do
    line_num=$((line_num + 1))
    
    if [[ $line == "---" ]]; then
      if [[ $in_frontmatter == false ]] && [[ $line_num -eq 1 ]]; then
        # Start of frontmatter
        in_frontmatter=true
        frontmatter="---"$'\n'
      elif [[ $in_frontmatter == true ]]; then
        # End of frontmatter
        frontmatter+="---"$'\n'
        in_frontmatter=false
        after_frontmatter=true
      fi
    elif [[ $in_frontmatter == true ]]; then
      # Inside frontmatter - process field
      if [[ $line =~ ^[[:space:]]*$ ]]; then
        # Empty line in frontmatter - preserve
        frontmatter+="$line"$'\n'
        in_handoffs=false
      elif [[ $line =~ ^handoffs: ]]; then
        # Start of handoffs block
        in_handoffs=true
        frontmatter+="$line"$'\n'
      elif [[ $in_handoffs == true ]] && [[ $line =~ ^[[:space:]]+ ]]; then
        # Inside handoffs block - convert context: to prompt:
        local converted_line="${line//context:/prompt:}"
        frontmatter+="$converted_line"$'\n'
      elif [[ $line =~ ^[^[:space:]] ]]; then
        # Non-indented line - exit handoffs block
        in_handoffs=false
        
        if [[ $line =~ ^tools: ]]; then
          # Normalize tool names
          local normalized_tools
          normalized_tools=$(normalize_tools "$line")
          frontmatter+="$normalized_tools"$'\n'
        elif [[ $line =~ ^model:[[:space:]]*(.+)$ ]]; then
          # Map model name
          local model_value="${BASH_REMATCH[1]}"
          local mapped_model
          mapped_model=$(map_model_name "$model_value")
          frontmatter+="model: $mapped_model"$'\n'
        elif [[ $line =~ ^(color|memory|maxTurns): ]]; then
          # Skip Claude-specific fields
          :
        else
          # Keep other fields as-is
          frontmatter+="$line"$'\n'
        fi
      elif [[ $line =~ ^tools: ]]; then
        # Normalize tool names
        local normalized_tools
        normalized_tools=$(normalize_tools "$line")
        frontmatter+="$normalized_tools"$'\n'
      elif [[ $line =~ ^model:[[:space:]]*(.+)$ ]]; then
        # Map model name
        local model_value="${BASH_REMATCH[1]}"
        local mapped_model
        mapped_model=$(map_model_name "$model_value")
        frontmatter+="model: $mapped_model"$'\n'
      elif [[ $line =~ ^(color|memory|maxTurns): ]]; then
        # Skip Claude-specific fields
        :
      else
        # Keep other fields as-is
        frontmatter+="$line"$'\n'
      fi
    elif [[ $after_frontmatter == true ]]; then
      # After frontmatter - collect rest of content
      content+="$line"$'\n'
    fi
  done 3< "$input_file"
  
  # Combine frontmatter and content
  echo -n "$frontmatter$content"
}

# Process a single agent file
process_agent_file() {
  local source_file="$1"
  local relative_path="${source_file#$SOURCE_DIR/}"
  local basename="${relative_path##*/}"
  local filename="${basename%.md}"
  
  # Target filename: name.agent.md
  local target_file="$TARGET_DIR/${filename}.agent.md"
  
  if [[ $VERBOSE == true ]]; then
    echo -e "${BLUE}Processing:${NC} $relative_path"
  fi
  
  # Check if source file has frontmatter
  if ! head -1 "$source_file" | grep -q "^---$"; then
    if [[ $VERBOSE == true ]]; then
      echo -e "${YELLOW}  Skipped:${NC} No frontmatter found"
    fi
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  
  # Convert frontmatter and content
  local converted_content
  if ! converted_content=$(convert_frontmatter "$source_file"); then
    echo -e "${YELLOW}  Error:${NC} Failed to convert $relative_path"
    ERRORS=$((ERRORS + 1))
    return
  fi
  
  # Write to target file (unless dry-run)
  if [[ $DRY_RUN == true ]]; then
    echo -e "${GREEN}  Would write:${NC} ${target_file#$REPO_ROOT/}"
    CONVERTED=$((CONVERTED + 1))
  else
    echo "$converted_content" > "$target_file"
    echo -e "${GREEN}  ✓ Converted:${NC} ${relative_path} → ${target_file#$REPO_ROOT/}"
    CONVERTED=$((CONVERTED + 1))
  fi
}

# Main execution
main() {
  echo "========================================"
  echo "Copilot Agents Generator"
  echo "========================================"
  echo ""
  echo "Source: $SOURCE_DIR"
  echo "Target: $TARGET_DIR"
  echo ""
  
  # Verify source directory exists
  if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
  fi
  
  # Create target directory if it doesn't exist
  if [[ ! -d "$TARGET_DIR" ]]; then
    if [[ $DRY_RUN == true ]]; then
      echo -e "${GREEN}Would create:${NC} $TARGET_DIR"
    else
      mkdir -p "$TARGET_DIR"
      echo -e "${GREEN}Created:${NC} $TARGET_DIR"
    fi
  fi
  
  # Find and process all .md files in source directory
  mapfile -t agent_files < <(find "$SOURCE_DIR" -type f -name "*.md")
  
  echo "Processing ${#agent_files[@]} agent files..."
  echo ""
  
  file_count=0
  for source_file in "${agent_files[@]}"; do
    file_count=$((file_count + 1))
    [[ $VERBOSE == true ]] && echo "[$file_count/${#agent_files[@]}] $source_file"
    process_agent_file "$source_file"
  done
  
  [[ $VERBOSE == true ]] && echo "Completed processing $file_count files"
  
  # Summary
  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "${GREEN}Converted:${NC} $CONVERTED"
  echo -e "${YELLOW}Skipped:${NC}   $SKIPPED"
  
  if [[ $ERRORS -gt 0 ]]; then
    echo -e "${YELLOW}Errors:${NC}    $ERRORS"
  fi
  
  echo ""
  
  if [[ $DRY_RUN == true ]]; then
    echo -e "${BLUE}Dry-run mode - no files were modified${NC}"
  else
    echo -e "${GREEN}✓ Generation complete${NC}"
  fi
}

# Run main
main
