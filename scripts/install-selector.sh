#!/bin/bash
# MyConvergio Selective Installation System
# Version: 1.0.0

set -e

AGENTS_SRC=".claude/agents"
AGENTS_LEAN=".claude/agents-lean"
RULES_SRC=".claude/rules"
RULES_CONSOLIDATED=".claude/rules/consolidated"
CLAUDE_HOME="$HOME/.claude"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  MyConvergio Installation Selector v3.7   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Select installation mode:"
    echo ""
    echo "  1) Minimal (Core agents only - ~50KB)"
    echo "     → 8 agents: ali, thor, baccio, rex, dario, otto, app-release, feature-release"
    echo ""
    echo "  2) Standard (Essential agents - ~200KB)"
    echo "     → 20 agents: Minimal + technical + leadership + compliance"
    echo ""
    echo "  3) Full (All 57 agents - ~800KB)"
    echo "     → Complete ecosystem"
    echo ""
    echo "  4) Lean (Full agents with stripped Security Frameworks - ~400KB)"
    echo "     → All agents but with optimized size"
    echo ""
    echo "  5) Custom (Interactive selection)"
    echo "     → Choose individual agents"
    echo ""
    echo "  6) Rules Only (No agents)"
    echo "     → Install rules/skills only"
    echo ""
    read -p "Enter choice [1-6]: " choice
    echo ""
}

install_minimal() {
    echo -e "${BLUE}Installing Minimal (Core agents)...${NC}"

    CORE_AGENTS=(
        "leadership_strategy/ali-chief-of-staff.md"
        "core_utility/thor-quality-assurance-guardian.md"
        "technical_development/baccio-tech-architect.md"
        "technical_development/rex-code-reviewer.md"
        "technical_development/dario-debugger.md"
        "technical_development/otto-performance-optimizer.md"
        "release_management/app-release-manager.md"
        "release_management/feature-release-manager.md"
    )

    mkdir -p "$CLAUDE_HOME/agents"

    for agent in "${CORE_AGENTS[@]}"; do
        cp "$AGENTS_SRC/$agent" "$CLAUDE_HOME/agents/$(basename $agent)"
        echo -e "  ${GREEN}✓${NC} $(basename $agent .md)"
    done

    # Copy Constitution (always needed)
    cp -r "$AGENTS_SRC/core_utility" "$CLAUDE_HOME/agents/"

    echo ""
    echo -e "${GREEN}✅ Installed 8 core agents${NC}"
}

install_standard() {
    echo -e "${BLUE}Installing Standard (Essential agents)...${NC}"

    CATEGORIES=(
        "leadership_strategy"
        "technical_development"
        "release_management"
        "compliance_legal"
        "core_utility"
    )

    mkdir -p "$CLAUDE_HOME/agents"

    for cat in "${CATEGORIES[@]}"; do
        if [ -d "$AGENTS_SRC/$cat" ]; then
            mkdir -p "$CLAUDE_HOME/agents/$cat"
            cp -r "$AGENTS_SRC/$cat"/* "$CLAUDE_HOME/agents/$cat/"
        fi
    done

    COUNT=$(find "$CLAUDE_HOME/agents" -name '*.md' ! -name 'CONSTITUTION.md' ! -name '*.md' -type f | wc -l | tr -d ' ')
    echo ""
    echo -e "${GREEN}✅ Installed $COUNT agents${NC}"
}

install_full() {
    echo -e "${BLUE}Installing Full (All 57 agents)...${NC}"

    mkdir -p "$CLAUDE_HOME/agents"
    cp -r "$AGENTS_SRC"/* "$CLAUDE_HOME/agents/"

    COUNT=$(find "$CLAUDE_HOME/agents" -name '*.md' ! -name 'CONSTITUTION.md' -type f | wc -l | tr -d ' ')
    echo ""
    echo -e "${GREEN}✅ Installed $COUNT agents${NC}"
}

install_lean() {
    echo -e "${BLUE}Installing Lean (Optimized agents)...${NC}"

    if [ ! -d "$AGENTS_LEAN" ]; then
        echo -e "${YELLOW}⚠️  Lean agents not yet available. Using full agents.${NC}"
        install_full
        return
    fi

    mkdir -p "$CLAUDE_HOME/agents"
    cp -r "$AGENTS_LEAN"/* "$CLAUDE_HOME/agents/"

    COUNT=$(find "$CLAUDE_HOME/agents" -name '*.md' -type f | wc -l | tr -d ' ')
    echo ""
    echo -e "${GREEN}✅ Installed $COUNT lean agents${NC}"
}

install_rules() {
    echo ""
    echo "Select rules mode:"
    echo "  1) Consolidated (Single file - 3.6KB)"
    echo "  2) Detailed (6 separate files - 52KB)"
    echo "  3) Both"
    read -p "Enter choice [1-3]: " rules_choice

    mkdir -p "$CLAUDE_HOME/rules"

    case $rules_choice in
        1)
            cp "$RULES_CONSOLIDATED/engineering-standards.md" "$CLAUDE_HOME/rules/"
            echo -e "  ${GREEN}✓${NC} Consolidated rules"
            ;;
        2)
            cp "$RULES_SRC"/*.md "$CLAUDE_HOME/rules/" 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} Detailed rules"
            ;;
        3)
            cp "$RULES_CONSOLIDATED/engineering-standards.md" "$CLAUDE_HOME/rules/"
            cp "$RULES_SRC"/*.md "$CLAUDE_HOME/rules/" 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} Both rule sets"
            ;;
    esac
}

install_skills() {
    if [ -d ".claude/skills" ]; then
        echo ""
        read -p "Install skills? [y/N]: " install_skills
        if [[ $install_skills =~ ^[Yy]$ ]]; then
            mkdir -p "$CLAUDE_HOME/skills"
            cp -r .claude/skills/* "$CLAUDE_HOME/skills/"
            echo -e "  ${GREEN}✓${NC} Skills installed"
        fi
    fi
}

show_summary() {
    echo ""
    echo -e "${BLUE}Installation Summary:${NC}"

    if [ -d "$CLAUDE_HOME/agents" ]; then
        AGENT_COUNT=$(find "$CLAUDE_HOME/agents" -name '*.md' ! -name 'CONSTITUTION.md' ! -name 'CommonValuesAndPrinciples.md' -type f | wc -l | tr -d ' ')
        AGENT_SIZE=$(du -sh "$CLAUDE_HOME/agents" 2>/dev/null | awk '{print $1}')
        echo "  Agents: $AGENT_COUNT ($AGENT_SIZE)"
    fi

    if [ -d "$CLAUDE_HOME/rules" ]; then
        RULES_COUNT=$(find "$CLAUDE_HOME/rules" -name '*.md' -type f | wc -l | tr -d ' ')
        RULES_SIZE=$(du -sh "$CLAUDE_HOME/rules" 2>/dev/null | awk '{print $1}')
        echo "  Rules:  $RULES_COUNT files ($RULES_SIZE)"
    fi

    if [ -d "$CLAUDE_HOME/skills" ]; then
        SKILLS_COUNT=$(find "$CLAUDE_HOME/skills" -type d -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
        echo "  Skills: $SKILLS_COUNT"
    fi

    echo ""
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo -e "${YELLOW}Tip:${NC} See docs/CONTEXT_OPTIMIZATION.md for usage tips"
}

main() {
    show_menu

    case $choice in
        1) install_minimal ;;
        2) install_standard ;;
        3) install_full ;;
        4) install_lean ;;
        5)
            echo -e "${YELLOW}Custom installation not yet implemented${NC}"
            exit 1
            ;;
        6)
            # Rules only
            ;;
        *)
            echo -e "${YELLOW}Invalid choice${NC}"
            exit 1
            ;;
    esac

    install_rules
    install_skills
    show_summary
}

main
