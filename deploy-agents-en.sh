#!/bin/bash

# MyConvergio Agent Deployment Script - CLEAN ENGLISH VERSION
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
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/claude-agents"

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️ INFO:${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    if [ ! -d "$AGENTS_DIR" ]; then
        print_error "Agents directory not found: $AGENTS_DIR"
        exit 1
    fi
    
    local agent_count=$(find "$AGENTS_DIR" -name "*.md" -type f | grep -v MICROSOFT_VALUES | wc -l)
    if [ "$agent_count" -lt 40 ]; then
        print_error "Found only $agent_count agents but expected 40 in $AGENTS_DIR"
        exit 1
    fi
    
    print_success "Prerequisites verified: $agent_count agents ready for installation"
}

# Main function
main() {
    clear
    
    # Check prerequisites
    check_prerequisites
    
    echo "🚀 MYCONVERGIO AGENTS INSTALLATION"
    echo "=================================="
    echo ""
    echo "WHAT THIS SCRIPT DOES:"
    echo "• Installs 40 specialized AI agents for Claude Code"
    echo "• They help with strategy, creativity, OKRs, communication, etc."
    echo "• Use them by typing @chief-of-staff or @creative-director"
    echo ""
    echo "THE AGENTS ARE (all with custom colors):"
    echo "👑 ali-chief-of-staff (Ali - master orchestrator) 🔵"
    echo "🎯 satya-board-of-directors (Satya) 🟣, matteo-strategic-business-architect (Matteo) 🟢, domik-mckinsey-strategic-decision-maker (Domik - McKinsey Partner) 🟢, antonio-strategy-expert (Antonio) 🔴"
    echo "⚡ luke-program-manager (Luke) 🔵, enrico-business-process-engineer (Enrico) 🟠, amy-cfo (Amy - CFO) 🟢"
    echo "🎨 jony-creative-director (Jony) 🟡, stefano-design-thinking-facilitator (Stefano) 🟡, coach-team-coach (Coach) 🟢"
    echo "🌍 dave-change-management-specialist (Dave) 🟣, behice-cultural-coach (Behice) 🟠"
    echo "🔧 baccio-tech-architect (Baccio) ⚫, thor-quality-assurance-guardian (Thor) 🟣, steve-executive-communication-strategist (Steve) ⚪"
    echo "♿ jenny-inclusive-accessibility-champion (Jenny - accessibility expert) 🟣"
    echo "✨ po-prompt-optimizer (Po - magical AI prompt optimization) 🟠"
    echo "🚀 sam-startupper (Sam - Y Combinator style startup founder) 🔴"
    echo "📋 taskmaster-strategic-task-decomposition-master (Taskmaster - task breakdown) ⚪"
    echo "👨‍💻 dan-engineering-gm (Dan - Microsoft style Engineering GM) 🟢"
    echo "🔍 ava-analytics-insights-virtuoso (Ava - ecosystem intelligence detective) 🟣"
    echo "🧠 marcus-context-memory-keeper (Marcus - institutional memory guardian) 🔘"
    echo "🔄 wanda-workflow-orchestrator (Wanda - systematic coordination templates) 🔴"
    echo "📊 diana-performance-dashboard (Diana - real-time ecosystem intelligence) 🟡"
    echo "🚀 xavier-coordination-patterns (Xavier - advanced multi-agent architectures) 🟢"
    echo ""
    
    # FIRST QUESTION - WHERE TO INSTALL
    echo "═══════════════════════════════════════════════════════════════════"
    echo "QUESTION 1: WHERE SHALL I INSTALL THEM?"
    echo ""
    echo "OPTION A = FOR ALL YOUR CLAUDE CODE PROJECTS"
    echo "• Agents work everywhere you open Claude Code"
    echo "• Installed in ~/.claude/agents/"
    echo "• Recommended if you use Claude Code for multiple projects"
    echo ""
    echo "OPTION B = ONLY FOR THIS PROJECT"
    echo "• Agents work only in this folder"
    echo "• Installed in .claude/agents/"
    echo "• Useful if you want to test them or use only here"
    echo ""
    
    local where=""
    while true; do
        echo "WHERE SHALL I INSTALL THEM?"
        read -p "Type A (all projects) or B (only here): " choice
        case $choice in
            [Aa])
                where="global"
                echo "✅ Installing for ALL PROJECTS (~/.claude/agents/)"
                break
                ;;
            [Bb])
                where="local"
                echo "✅ Installing ONLY HERE (.claude/agents/)"
                break
                ;;
            *)
                echo "❌ Type 'A' for all projects or 'B' for only here"
                echo ""
                ;;
        esac
    done
    
    echo ""
    
    # SECOND QUESTION - HOW MANY AGENTS
    echo "═══════════════════════════════════════════════════════════════════"
    echo "QUESTION 2: HOW MANY AGENTS SHALL I INSTALL?"
    echo ""
    echo "OPTION 1 = ALL 40 AGENTS"
    echo "• Complete MyConvergio suite"
    echo "• Installation in 30 seconds"
    echo "• Recommended to have everything ready"
    echo ""
    echo "OPTION 2 = ONLY SOME AGENTS"
    echo "• You choose which ones to install"
    echo "• Lighter installation"
    echo "• You can add more later"
    echo ""
    
    local agents=""
    while true; do
        echo "HOW MANY AGENTS SHALL I INSTALL?"
        read -p "Type 1 (all) or 2 (some): " choice
        case $choice in
            1)
                agents="all"
                echo "✅ I will install ALL 40 AGENTS"
                break
                ;;
            2)
                echo ""
                echo "AVAILABLE AGENTS:"
                echo "ali-chief-of-staff, satya-board-of-directors, matteo-strategic-business-architect,"
                echo "domik-mckinsey-strategic-decision-maker, taskmaster-strategic-task-decomposition-master,"
                echo "antonio-strategy-expert, luke-program-manager, davide-project-manager,"
                echo "enrico-business-process-engineer, amy-cfo, fabio-sales-business-development,"
                echo "jony-creative-director, stefano-design-thinking-facilitator, coach-team-coach,"
                echo "dave-change-management-specialist, behice-cultural-coach,"
                echo "baccio-tech-architect, thor-quality-assurance-guardian,"
                echo "steve-executive-communication-strategist, jenny-inclusive-accessibility-champion,"
                echo "po-prompt-optimizer, sam-startupper, dan-engineering-gm, ava-analytics-insights-virtuoso,"
                echo "marcus-context-memory-keeper, wanda-workflow-orchestrator, diana-performance-dashboard,"
                echo "xavier-coordination-patterns"
                echo ""
                read -p "Write agent names separated by commas: " agents
                echo "✅ I will install the agents: $agents"
                break
                ;;
            *)
                echo "❌ Type '1' for all or '2' for some"
                echo ""
                ;;
        esac
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "INSTALLATION IN PROGRESS..."
    echo ""
    
    # Determine target directory
    if [ "$where" = "global" ]; then
        target_dir="$HOME/.claude/agents"
    else
        target_dir=".claude/agents"
    fi
    
    # Create directory if it doesn't exist
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would create directory: $target_dir"
    else
        mkdir -p "$target_dir"
    fi
    
    # CLEANUP: Remove all old agents before installing new ones
    print_info "Cleaning existing agents..."
    if [ -d "$target_dir" ]; then
        local old_agents=$(find "$target_dir" -name "*.md" -type f | wc -l)
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY-RUN] Would remove $old_agents old agents from $target_dir"
        else
            # Remove only .md files (agents) from target directory
            find "$target_dir" -name "*.md" -type f -delete 2>/dev/null || true
            print_success "Old agents removed from $target_dir"
        fi
    fi
    
    # Install agents
    local count=0
    if [ "$agents" = "all" ]; then
        for agent_file in "$AGENTS_DIR"/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file" .md)
                if [ "$DRY_RUN" = true ]; then
                    echo "✅ [DRY-RUN] Would install: $agent_name"
                else
                    cp "$agent_file" "$target_dir/"
                    echo "✅ Installed: $agent_name"
                fi
                count=$((count + 1))
            fi
        done
    else
        IFS=',' read -ra AGENT_ARRAY <<< "$agents"
        for agent_name in "${AGENT_ARRAY[@]}"; do
            agent_name=$(echo "$agent_name" | xargs)  # remove spaces
            agent_file="$AGENTS_DIR/${agent_name}.md"
            if [ -f "$agent_file" ]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "✅ [DRY-RUN] Would install: $agent_name"
                else
                    cp "$agent_file" "$target_dir/"
                    echo "✅ Installed: $agent_name"
                fi
                count=$((count + 1))
            else
                echo "❌ Not found: $agent_name"
            fi
        done
    fi
    
    echo ""
    echo "🎉 INSTALLATION COMPLETED!"
    echo "=========================="
    print_success "$count agents installed in $target_dir"
    
    # Post-installation verification
    echo ""
    print_info "Verifying installation..."
    local installed_count=$(find "$target_dir" -name "*.md" -type f | wc -l)
    if [ "$installed_count" -eq "$count" ]; then
        print_success "Verification completed: all agents installed correctly"
    else
        print_error "Possible issue: found $installed_count files but expected $count"
    fi
    echo ""
    echo "HOW TO USE THEM:"
    echo "1. Open Claude Code"
    echo "2. Type @ and you'll see your agents"
    echo "3. Try: @ali-chief-of-staff Ali, help me plan the project"
    echo ""
    echo "EXAMPLES:"
    echo "@jony-creative-director Jony, I need an innovative name for our product"
    echo "@antonio-strategy-expert Antonio, create OKRs for our Q4 team"
    echo "@behice-cultural-coach Behice, explain Japanese business culture to me"
    echo "@po-prompt-optimizer Po, optimize this prompt for Claude Sonnet 4"
    echo "@sam-startupper Sam, help me create a pitch deck for my startup"
    echo "@dan-engineering-gm Dan, engineering strategy to scale from 10 to 100 developers"
    echo "@ava-analytics-insights-virtuoso Ava, analyze our ecosystem performance patterns"
    echo "@marcus-context-memory-keeper Marcus, what architectural decisions did we make last month?"
    echo "@wanda-workflow-orchestrator Wanda, create a systematic product launch template"
    echo "@diana-performance-dashboard Diana, show me real-time agent utilization metrics"
    echo "@xavier-coordination-patterns Xavier, design swarm intelligence for crisis management"
    echo ""
    echo "🔥 Ali (Chief of Staff) automatically coordinates all other agents!"
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo "📝 NOTE: This was a simulation. To actually install run without --dry-run"
    else
        echo "💡 TIP: To test without installing use: ./deploy-agents-en.sh --dry-run"
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi