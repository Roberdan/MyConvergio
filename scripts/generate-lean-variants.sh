#!/usr/bin/env bash
set -euo pipefail

# generate-lean-variants.sh
# Generates lean variants of MyConvergio agents by stripping verbose sections
# Usage: ./generate-lean-variants.sh [agent-file.md] or ./generate-lean-variants.sh --all

AGENTS_DIR=".claude/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate lean variant
generate_lean() {
    local input_file="$1"
    local output_file="${input_file%.md}.lean.md"
    
    log_info "Processing: $input_file"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "File not found: $input_file"
        return 1
    fi
    
    # Check if already a lean variant
    if [[ "$input_file" == *.lean.md ]]; then
        log_warning "Skipping: already a lean variant"
        return 0
    fi
    
    # Create lean version using awk
    awk '
        BEGIN {
            in_security = 0
            in_copyright = 0
            in_example = 0
            skip_next_blank = 0
            printed_something = 0
        }
        
        # Detect Security & Ethics Framework section
        /^## Security & Ethics Framework/ {
            in_security = 1
            next
        }
        
        # Detect Copyright section
        /^<!--$/ {
            getline
            if (/Copyright \(c\)/) {
                in_copyright = 1
                next
            }
        }
        
        # End copyright section
        /^-->$/ && in_copyright {
            in_copyright = 0
            skip_next_blank = 1
            next
        }
        
        # Detect end of Security Framework (next ## heading)
        /^## / && in_security && !/^## Security & Ethics Framework/ {
            in_security = 0
            skip_next_blank = 0
        }
        
        # Detect Example sections in description
        /Example:/ && NR < 20 {
            in_example = 1
            next
        }
        
        # End example in frontmatter
        /^tools:/ || /^color:/ || /^model:/ {
            in_example = 0
        }
        
        # Skip blank line after removed section
        /^$/ && skip_next_blank {
            skip_next_blank = 0
            next
        }
        
        # Skip lines in removed sections
        in_security || in_copyright || in_example {
            next
        }
        
        # Print everything else
        {
            print
            printed_something = 1
        }
    ' "$input_file" > "$output_file"
    
    # Verify output was created and has content
    if [[ ! -s "$output_file" ]]; then
        log_error "Failed to generate lean variant (empty output)"
        rm -f "$output_file"
        return 1
    fi
    
    # Calculate size reduction
    original_size=$(wc -c < "$input_file")
    lean_size=$(wc -c < "$output_file")
    reduction=$(( 100 - (lean_size * 100 / original_size) ))
    
    log_success "Created: $output_file (${reduction}% smaller)"
    
    return 0
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    if [[ $# -eq 0 ]] || [[ "$1" == "--all" ]]; then
        log_info "Generating lean variants for all agents..."
        
        # Find all agent files (excluding already lean variants)
        find "$AGENTS_DIR" -name "*.md" -not -name "*.lean.md" -not -name "CONSTITUTION.md" -not -name "CommonValuesAndPrinciples.md" -not -name "MICROSOFT_VALUES.md" -not -name "SECURITY_FRAMEWORK_TEMPLATE.md" | while read -r agent_file; do
            generate_lean "$agent_file"
        done
        
        log_success "Lean variant generation complete"
    else
        # Process single file
        generate_lean "$1"
    fi
}

main "$@"
