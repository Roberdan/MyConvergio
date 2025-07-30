#!/bin/bash

# =============================================================================
# MYCONVERGIO AGENTS DEPLOYMENT SCRIPT
# =============================================================================
# Version: 2.0.0
# Last Updated: $(date +"%Y-%m-%d")
#
# 🚀 ABOUT MYCONVERGIO
# MyConvergio is an experimental open-source collection of 40+ specialized 
# Claude Code subagents designed to demonstrate the potential of coordinated 
# AI agent ecosystems for enterprise software project management, strategic 
# leadership, and organizational excellence.
#
# 🔍 WHAT THIS SCRIPT DOES
# This script helps you deploy MyConvergio agents to your Claude Code 
# environment. It supports installing agents either globally (for all projects) 
# or locally (for the current project only).
#
# 📂 DIRECTORY STRUCTURE
# The agents are organized into the following categories:
# - leadership_strategy: Strategic leadership and decision-making agents
# - technical_development: Technical implementation and architecture experts
# - business_operations: Business process and operational excellence agents
# - design_ux: Design and user experience specialists
# - compliance_legal: Compliance, legal, and ethical considerations
# - specialized_experts: Niche expertise and specialized knowledge
# - core_utility: Essential utilities and foundational agents
#
# ⚠️  EXPERIMENTAL NOTICE
# This is experimental software provided for research and educational purposes 
# only. It is not intended for production use or handling of sensitive data.
#
# 📄 LICENSE
# Copyright (c) 2025 Convergio.io
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0
# =============================================================================

set -e

# Parse command line arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🧪 DRY-RUN MODE: Simulation without changes"
    echo ""
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/claude-agents"
VERSION_MANAGER="$SCRIPT_DIR/scripts/version-manager.sh"

# Agent categories with descriptions
CATEGORIES=(
    "leadership_strategy"
    "technical_development"
    "business_operations"
    "design_ux"
    "compliance_legal"
    "specialized_experts"
    "core_utility"
)

# Category descriptions
CATEGORY_DESCRIPTIONS=(
    "🎯 Leadership & Strategy: Strategic decision-making, executive leadership, and organizational vision"
    "💻 Technical Development: Software architecture, coding, and technical implementation experts"
    "📊 Business Operations: Process optimization, operations, and business excellence"
    "🎨 Design & UX: User experience, interface design, and creative direction"
    "⚖️ Compliance & Legal: Regulatory compliance, legal considerations, and ethical guidelines"
    "🔍 Specialized Experts: Niche expertise across various domains and industries"
    "🛠️ Core Utilities: Foundational agents and essential tools for the ecosystem"
)

# Helper functions for colored output
print_error() { echo -e "${RED} ERROR:${NC} $1"; }
print_success() { echo -e "${GREEN} SUCCESS:${NC} $1"; }
print_info() { echo -e "${BLUE} INFO:${NC} $1"; }
print_warning() { echo -e "${YELLOW} WARNING:${NC} $1"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
print_subheader() { echo -e "\n${BLUE} $1${NC}"; }

# Check prerequisites and versions
check_prerequisites() {
    if [ ! -d "$AGENTS_DIR" ]; then
        print_error "Agents directory not found: $AGENTS_DIR"
        exit 1
    fi
    
    local agent_count=0
    for category in "${CATEGORIES[@]}"; do
        if [ -d "$AGENTS_DIR/$category" ]; then
            count=$(find "$AGENTS_DIR/$category" -name "*.md" -type f | wc -l)
            agent_count=$((agent_count + count))
        fi
    done
    
    if [ "$agent_count" -lt 30 ]; then
        print_info "Found $agent_count agents. Some might be missing."
    else
        print_success "Found $agent_count agents in the repository"
    fi
    
    # Ensure version manager is executable
    if [ -f "$VERSION_MANAGER" ]; then
        chmod +x "$VERSION_MANAGER"
        # Scan for new agents and update versions
        "$VERSION_MANAGER" scan
    else
        print_warning "Version manager not found at $VERSION_MANAGER. Version tracking will be limited."
    fi
}

# Main function
main() {
    clear
    check_prerequisites
    
    echo ""
    echo " MYCONVERGIO AGENTS INSTALLATION"
    echo "=================================="
    echo ""
    echo "Welcome to MyConvergio - Your AI-Powered Strategic Partner"
    echo ""
    echo "This installation will help you set up specialized AI agents to enhance"
    echo "your Claude Code experience. You can install agents globally (all projects)"
    echo "or locally (this project only)."
    echo ""
    echo "AGENT CATEGORIES:"
    echo " Leadership & Strategy: Strategic decision-making and leadership"
    echo " Technical Development: Software architecture and implementation"
    echo " Business Operations: Process optimization and operations"
    echo " Design & UX: User experience and interface design"
    echo " Compliance & Legal: Regulatory and ethical considerations"
    echo " Specialized Experts: Niche expertise across domains"
    echo " Core Utilities: Essential tools and foundational agents"
    echo ""
    echo "RECOMMENDED: Install all agents for the full MyConvergio experience."
    echo ""
    echo "NOTE: This is an experimental project. See documentation for details."
    
    # WHERE TO INSTALL
    print_header "INSTALLATION LOCATION"
    echo "Choose where to install the agents:"
    echo ""
    echo "A) All Projects (Recommended)"
    echo "   Installs agents in ~/.claude/agents/"
    echo "   Available across all your Claude Code projects"
    echo "   Best for most users who want system-wide access"
    echo ""
    echo "B) This Project Only"
    echo "   Installs agents in .claude/agents/ (current directory)"
    echo "   Only available within this specific project"
    echo "   Useful for project-specific agent customizations"
    echo ""
    echo "Note: You can always run this script again to modify your installation."
    
    local where=""
    while true; do
        read -p "Choose (A/B): " choice
        case $choice in
            [Aa]) where="global"; break ;;
            [Bb]) where="local"; break ;;
            *) echo "Please choose A or B" ;;
        esac
    done
    
    # WHICH AGENTS TO INSTALL
    print_header "AGENT SELECTION"
    echo "Choose how to select agents for installation:"
    echo ""
    echo "1) All Agents (Recommended)"
    echo "   Installs all 40+ specialized agents"
    echo "   Provides complete MyConvergio functionality"
    echo "   Recommended for most users"
    echo ""
    echo "2) By Category"
    echo "   Select from predefined agent categories"
    echo "   Good for installing specific functional areas"
    echo "   Example: Install only Technical Development agents"
    echo ""
    echo "3) Custom Selection"
    echo "   Hand-pick individual agents to install"
    echo "   Advanced users can create custom configurations"
    echo "   Useful for minimal or specialized deployments"
    echo ""
    echo "Tip: You can always run this script again to add or remove agents."
    
    local install_mode=""
    while true; do
        read -p "Choose (1-3): " choice
        case $choice in
            1) install_mode="all"; break ;;
            2) install_mode="category"; break ;;
            3) install_mode="custom"; break ;;
            *) echo "Please choose 1, 2, or 3" ;;
        esac
    done
    
    # Process selection
    local selected_categories=()
    
    if [ "$install_mode" = "category" ]; then
        print_header "AVAILABLE CATEGORIES"
        echo "Select one or more categories to install:"
        echo ""
        
        # Display categories with descriptions
        for i in "${!CATEGORIES[@]}"; do
            echo "${GREEN}$((i+1))) ${CATEGORY_DESCRIPTIONS[$i]}${NC}"
            echo "   Path: claude-agents/${CATEGORIES[$i]}/"
            
            # Count agents in this category
            local agent_count=$(find "$AGENTS_DIR/${CATEGORIES[$i]}" -name "*.md" -type f 2>/dev/null | wc -l)
            echo "   Agents: ${GREEN}${agent_count}${NC} specialized agents"
            echo ""
        done
        
        echo "Example: To select categories 1, 3, and 5, type: 1,3,5"
        read -p "Enter category numbers (comma-separated): " selected_categories
        
        # Convert to array and validate
        IFS=',' read -ra categories <<< "$selected_categories"
        selected_agents=()
        for cat_num in "${categories[@]}"; do
            if [[ "$cat_num" =~ ^[0-9]+$ ]] && [ "$cat_num" -ge 1 ] && [ "$cat_num" -le ${#CATEGORIES[@]} ]; then
                selected_agents+=("${CATEGORIES[$((cat_num-1))]}")
            fi
        done
        
        if [ ${#selected_agents[@]} -eq 0 ]; then
            print_error "No valid categories selected"
            exit 1
        fi
        
        echo ""
        print_success "Selected ${#selected_agents[@]} categories for installation"
    fi
    
    # TARGET DIRECTORY
    if [ "$where" = "global" ]; then
        target_dir="$HOME/.claude/agents"
    else
        target_dir="$SCRIPT_DIR/.claude/agents"
    fi
    
    # Install agents
    echo ""
    echo "INSTALLING AGENTS..."
    
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$target_dir"
        find "$target_dir" -name "*.md" -type f -delete 2>/dev/null || true
    fi
    
    local count=0
    
    if [ "$install_mode" = "all" ]; then
        # Install all agents
        for category in "${CATEGORIES[@]}"; do
            if [ -d "$AGENTS_DIR/$category" ]; then
                find "$AGENTS_DIR/$category" -name "*.md" -type f | while read -r agent_file; do
                    agent_name=$(basename "$agent_file")
                    if [ "$DRY_RUN" = true ]; then
                        echo "[DRY-RUN] Would install: $agent_name"
                    else
                        cp "$agent_file" "$target_dir/"
                        echo "Installed: $agent_name"
                    fi
                    count=$((count + 1))
                done
            fi
        done
    elif [ "$install_mode" = "category" ]; then
        # Install by category
        for category in "${selected_agents[@]}"; do
            if [ -d "$AGENTS_DIR/$category" ]; then
                find "$AGENTS_DIR/$category" -name "*.md" -type f | while read -r agent_file; do
                    local agent_name=$(basename "$agent_file" .md)
                    local version=""
                    
                    # Get version if version manager is available
                    if [ -f "$VERSION_MANAGER" ]; then
                        version=$("$VERSION_MANAGER" agent-version "$agent_name" 2>/dev/null || echo "0.0.0")
                    fi
                    
                    if [ "$DRY_RUN" = true ]; then
                        echo "[DRY-RUN] Would install: $agent_name ${version:+v$version}"
                    else
                        cp "$agent_file" "$target_dir/"
                        
                        # Add version info to agent file if not present
                        if ! grep -q "^version:" "$target_dir/$agent_name.md"; then
                            echo -e "\n---\nversion: $version\n---\n" >> "$target_dir/$agent_name.md"
                        fi
                        
                        print_success "Installed: $agent_name ${version:+v$version}"
                    fi
                done
            fi
        done
    else
        # Custom selection
        echo ""
        echo "AVAILABLE AGENTS:"
        for category in "${CATEGORIES[@]}"; do
            if [ -d "$AGENTS_DIR/$category" ]; then
                find "$AGENTS_DIR/$category" -name "*.md" -type f -exec basename {} \; | sed 's/\.md$//' | sort
            fi
        done | sort
        
        echo ""
        read -p "Enter agent names (comma-separated): " agent_list
        
        IFS=',' read -ra AGENT_ARRAY <<< "$agent_list"
        for agent in "${AGENT_ARRAY[@]}"; do
            agent=$(echo "$agent" | xargs)
            agent_found=false
            
            for category in "${CATEGORIES[@]}"; do
                if [ -f "$AGENTS_DIR/$category/$agent.md" ]; then
                    if [ "$DRY_RUN" = true ]; then
                        echo "[DRY-RUN] Would install: $agent"
                    else
                        cp "$AGENTS_DIR/$category/$agent.md" "$target_dir/"
                        echo "Installed: $agent"
                    fi
                    count=$((count + 1))
                    agent_found=true
                    break
                fi
            done
            
            if [ "$agent_found" = false ]; then
                echo "Not found: $agent"
            fi
        done
    fi
    
    # Results
    echo ""
    if [ "$DRY_RUN" = true ]; then
        print_success "DRY RUN: Would install $count agents to $target_dir"
        echo "Run without --dry-run to perform actual installation."
    else
        print_success "SUCCESS: $count agents installed to $target_dir"
        echo ""
        echo "HOW TO USE:"
        echo "1. Open Claude Code"
        echo "2. Type @ to see your agents"
        echo "3. Example: @ali-chief-of-staff Help me plan this project"
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
