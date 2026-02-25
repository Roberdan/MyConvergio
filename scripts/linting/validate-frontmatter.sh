#!/usr/bin/env bash
# validate-frontmatter.sh - Validates YAML frontmatter in markdown files against JSON schemas
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$SCRIPT_DIR/schemas"
SCHEMA_MAPPING="$SCHEMA_DIR/schema-mapping.json"
EXIT_CODE=0

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validates YAML frontmatter in markdown files against JSON schemas.

OPTIONS:
  --help    Show this help message

DESCRIPTION:
  Reads schema-mapping.json, finds matching files via glob patterns,
  extracts YAML frontmatter (between --- markers), converts to JSON,
  and validates against the mapped schema. Reports file:line on failure.
  
  Exits 0 if all validations pass, 1 if any validation fails.

DEPENDENCIES:
  - python3
  - jsonschema (Python package)
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found" >&2
  exit 1
fi

if ! python3 -c "import jsonschema" 2>/dev/null; then
  echo "ERROR: jsonschema Python package not installed" >&2
  exit 1
fi

if [[ ! -f "$SCHEMA_MAPPING" ]]; then
  echo "ERROR: schema-mapping.json not found at $SCHEMA_MAPPING" >&2
  exit 1
fi

python3 - "$SCHEMA_DIR" "$SCHEMA_MAPPING" <<'PYTHON_SCRIPT'
import sys
import json
import yaml
import re
from pathlib import Path
from glob import glob
from jsonschema import validate, ValidationError, SchemaError

schema_dir = Path(sys.argv[1])
mapping_file = Path(sys.argv[2])
exit_code = 0

with open(mapping_file) as f:
    config = json.load(f)

def extract_frontmatter(filepath):
    """Extract YAML frontmatter from markdown file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    if not lines or not lines[0].strip() == '---':
        return None, None
    
    frontmatter_lines = []
    start_line = 1
    end_line = None
    
    for i, line in enumerate(lines[1:], start=2):
        if line.strip() == '---':
            end_line = i
            break
        frontmatter_lines.append(line)
    
    if end_line is None:
        return None, None
    
    frontmatter_text = ''.join(frontmatter_lines)
    if not frontmatter_text.strip():
        return None, None
    
    try:
        data = yaml.safe_load(frontmatter_text)
        return data, start_line
    except yaml.YAMLError as e:
        return None, start_line

def should_exclude(filepath, exclude_list):
    """Check if file should be excluded."""
    filepath_str = str(filepath)
    for exclude_pattern in exclude_list:
        if filepath_str.endswith(exclude_pattern):
            return True
    return False

for mapping in config['mappings']:
    pattern = mapping['pattern']
    schema_file = schema_dir / mapping['schema']
    exclude_list = mapping.get('exclude', [])
    
    if not schema_file.exists():
        print(f"ERROR: Schema file not found: {schema_file}", file=sys.stderr)
        exit_code = 1
        continue
    
    with open(schema_file) as f:
        schema = json.load(f)
    
    # Find matching files
    files = glob(pattern, recursive=True)
    
    for filepath in files:
        filepath_path = Path(filepath)
        
        if should_exclude(filepath_path, exclude_list):
            continue
        
        if not filepath_path.exists():
            continue
        
        frontmatter, start_line = extract_frontmatter(filepath)
        
        if frontmatter is None:
            if start_line is not None:
                print(f"{filepath}:{start_line}: ERROR: Invalid YAML frontmatter", file=sys.stderr)
                exit_code = 1
            # No frontmatter found - skip silently
            continue
        
        try:
            validate(instance=frontmatter, schema=schema)
        except ValidationError as e:
            error_path = ' -> '.join(str(p) for p in e.path) if e.path else 'root'
            print(f"{filepath}:{start_line}: ERROR: Validation failed at {error_path}: {e.message}", file=sys.stderr)
            exit_code = 1
        except SchemaError as e:
            print(f"{filepath}:{start_line}: ERROR: Invalid schema: {e.message}", file=sys.stderr)
            exit_code = 1

sys.exit(exit_code)
PYTHON_SCRIPT

exit $?
