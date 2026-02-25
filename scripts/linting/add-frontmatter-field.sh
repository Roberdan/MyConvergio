#!/usr/bin/env bash
set -euo pipefail

# add-frontmatter-field.sh - Safely insert YAML field into markdown frontmatter
# Usage: add-frontmatter-field.sh <field> <value> <glob-pattern> [--dry-run]

show_help() {
  cat << EOF
Usage: add-frontmatter-field.sh <field> <value> <glob-pattern> [--dry-run]

Safely inserts a new YAML field into existing frontmatter of markdown files.

Arguments:
  field         Field name to insert (e.g., "status")
  value         Value for the field (e.g., "draft")
  glob-pattern  File pattern to match (e.g., "docs/**/*.md")

Options:
  --dry-run     Show what would be changed without modifying files
  --help        Show this help message

Examples:
  add-frontmatter-field.sh status draft "docs/**/*.md"
  add-frontmatter-field.sh version 1.0 "*.md" --dry-run

Behavior:
  - Finds all files matching the glob pattern
  - Checks if field already exists in frontmatter (skips if found)
  - Inserts field after the last existing field before closing '---'
  - Preserves existing formatting and field order
  - Only processes files with valid frontmatter (opening and closing '---')

Exit codes:
  0 - Success (files processed or skipped appropriately)
  1 - Invalid arguments or no files found
  2 - File processing error
EOF
}

# Parse arguments
if [[ $# -lt 1 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi

if [[ $# -lt 3 ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Run with --help for usage information" >&2
  exit 1
fi

FIELD="$1"
VALUE="$2"
GLOB_PATTERN="$3"
DRY_RUN=false

if [[ $# -eq 4 ]] && [[ "$4" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Validate field name (simple YAML key validation)
if ! [[ "$FIELD" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
  echo "Error: Invalid field name '$FIELD'. Must start with letter/underscore, contain only alphanumerics, underscores, hyphens." >&2
  exit 1
fi

# Find files matching glob pattern
mapfile -t files < <(find . -type f -path "./$GLOB_PATTERN" 2>/dev/null | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Error: No files found matching pattern '$GLOB_PATTERN'" >&2
  exit 1
fi

echo "Found ${#files[@]} file(s) matching '$GLOB_PATTERN'"
if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY RUN MODE - No files will be modified]"
fi
echo ""

processed=0
skipped=0
errors=0

for file in "${files[@]}"; do
  # Check if file has frontmatter (starts with ---)
  if ! head -n 1 "$file" 2>/dev/null | grep -q "^---$"; then
    echo "⊘ $file - No frontmatter found (skipped)"
    ((skipped++))
    continue
  fi

  # Extract frontmatter (lines between first --- and second ---)
  frontmatter=$(awk '/^---$/{if(++count==2) exit; if(count==1) next} count==1' "$file")
  
  # Check if frontmatter has closing ---
  closing_line=$(awk '/^---$/{count++; if(count==2){print NR; exit}}' "$file")
  closing_line=${closing_line:-0}
  if [[ "$closing_line" -eq 0 ]]; then
    echo "⊘ $file - Malformed frontmatter, no closing '---' (skipped)"
    ((skipped++))
    continue
  fi

  # Check if field already exists
  if echo "$frontmatter" | grep -q "^${FIELD}:"; then
    echo "⊘ $file - Field '$FIELD' already exists (skipped)"
    ((skipped++))
    continue
  fi

  # Prepare new field line with proper indentation
  new_field="${FIELD}: ${VALUE}"

  if [[ "$DRY_RUN" == true ]]; then
    echo "✓ $file - Would insert '$new_field' at line $closing_line"
    ((processed++))
  else
    # Create temp file
    temp_file=$(mktemp)
    
    # Insert new field before closing ---
    if awk -v line="$closing_line" -v field="$new_field" \
      'NR==line {print field} {print}' "$file" > "$temp_file"; then
      
      # Replace original file
      if mv "$temp_file" "$file"; then
        echo "✓ $file - Inserted '$new_field'"
        ((processed++))
      else
        echo "✗ $file - Failed to write changes" >&2
        rm -f "$temp_file"
        ((errors++))
      fi
    else
      echo "✗ $file - Failed to process" >&2
      rm -f "$temp_file"
      ((errors++))
    fi
  fi
done

echo ""
echo "Summary:"
echo "  Processed: $processed"
echo "  Skipped:   $skipped"
echo "  Errors:    $errors"

if [[ $errors -gt 0 ]]; then
  exit 2
fi

exit 0
