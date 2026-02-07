#!/bin/bash
# Install missing CLI tools for optimal Claude Code experience
# Run: ~/.claude/scripts/install-missing-tools.sh

set -e

echo "=== Installing Missing Tools ==="

# Check if Homebrew is available
if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew not found. Install from https://brew.sh"
    exit 1
fi

# Tools to install
TOOLS=(
    "prettier"        # JS/TS/CSS/MD formatter
    "shfmt"           # Shell script formatter
    "zoxide"          # Smart cd with frecency
    "tlrc"            # Simplified man pages (tldr client)
    "onefetch"        # Git repo summary
    "ast-grep"        # Semantic code search
    "universal-ctags" # Code symbol indexing
)

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo "✅ $tool already installed"
    else
        echo "📦 Installing $tool..."
        brew install "$tool"
        echo "✅ $tool installed"
    fi
done

echo ""
echo "=== Post-Install Configuration ==="

# Configure zoxide if just installed
if command -v zoxide &>/dev/null; then
    echo "zoxide: Add to your shell config:"
    echo '  eval "$(zoxide init zsh)"  # for zsh'
    echo '  eval "$(zoxide init bash)" # for bash'
fi

echo ""
echo "=== Verification ==="
echo "prettier: $(prettier --version 2>/dev/null || echo 'not found')"
echo "shfmt:    $(shfmt --version 2>/dev/null || echo 'not found')"
echo "zoxide:   $(zoxide --version 2>/dev/null || echo 'not found')"
echo "tlrc:     $(tlrc --version 2>/dev/null || echo 'not found')"

echo ""
echo "✅ Done! All tools installed."
