#!/bin/bash

# =============================================================================
# MYCONVERGIO AGENTS DEPLOYMENT SCRIPT
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# MYCONVERGIO AGENTS DEPLOYMENT SCRIPT
# =============================================================================
# Version: 2.1.0
# Last Updated: $(date +"%Y-%m-%d")
# Language: Bilingual (Italian/English)
#
# ABOUT MYCONVERGIO
# MyConvergio is an experimental open-source collection of 40+ specialized 
# Claude Code subagents designed to demonstrate the potential of coordinated 
# AI agent ecosystems for enterprise software project management, strategic 
# leadership, and organizational excellence.
#
# WHAT THIS SCRIPT DOES
# This script helps you deploy MyConvergio agents to your Claude Code 
# environment. It supports installing agents either globally (for all projects) 
# or locally (for the current project only).
#
# DIRECTORY STRUCTURE
# The agents are organized into the following categories:
# - leadership_strategy: Strategic leadership and decision-making agents
# - technical_development: Technical implementation and architecture experts
# - business_operations: Business process and operational excellence agents
# - design_ux: Design and user experience specialists
# - compliance_legal: Compliance, legal, and ethical considerations
# - specialized_experts: Niche expertise and specialized knowledge
# - core_utility: Essential utilities and foundational agents
#
# EXPERIMENTAL NOTICE
# This is experimental software provided for research and educational purposes 
# only. It is not intended for production use or handling of sensitive data.
#
# LICENSE
# Copyright (c) 2025 Convergio.io
# Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0
# =============================================================================

set -e

# Function to select language
select_language() {
    clear
    echo ""
    echo " ================================"
    echo "  SCEGLI LINGUA / SELECT LANGUAGE"
    echo " ================================"
    echo ""
    echo " 1) Italiano"
    echo " 2) English"
    echo ""
    
    while true; do
        read -p "Seleziona / Select (1-2): " lang_choice
        case $lang_choice in
            1) LANG="it"; break ;;
            2) LANG="en"; break ;;
            *) echo "Scelta non valida / Invalid choice";;
        esac
    done
}

# Initialize variables
DRY_RUN=false
SELECT_DIR=false
LANG=""
AUTO_SELECT=false
DEST_DIR="."

# Show language selection if not set via command line
if [ -z "$LANG" ]; then
    select_language
fi

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --lang=*)
            LANG="${arg#*=}"
            AUTO_SELECT=true
            shift
            ;;
        -l=*)
            LANG="${arg#*=}"
            AUTO_SELECT=true
            shift
            ;;
        --select-dir)
            SELECT_DIR=true
            shift
            ;;
        --dest=*)
            DEST_DIR="${arg#*=}"
            shift
            ;;
        *)
            # Any other argument is treated as destination directory
            if [[ -n "$arg" && "$arg" != "--dry-run" && "$arg" != "--select-dir" && ! "$arg" =~ ^--lang= ]]; then
                DEST_DIR="$arg"
                shift
            fi
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo " DRY-RUN MODE: Simulation without changes"
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
VERSION_MANAGER="$SCRIPT_DIR/scripts/version-manager.sh"

# Language selection
if [ -z "$LANG" ]; then
    echo -e "\n${BLUE}🌐 Seleziona la lingua / Select language:${NC}"
    echo "1. Italiano"
    echo "2. English"
    read -p "Scelta / Choice [1-2]: " lang_choice
    
    case $lang_choice in
        1) LANG="it" ;;
        2) LANG="en" ;;
        *) LANG="en" ;;
    esac
fi

# Set language-specific variables
if [ "$LANG" = "it" ]; then
    AGENTS_DIR="$SCRIPT_DIR/claude-agenti"
    MSG_LANG="Italiano"
    MSG_DEPLOY="Distribuzione agenti MyConvergio"
    MSG_SELECT_DIR="Seleziona la directory di destinazione"
    MSG_ENTER_DIR="Inserisci il percorso della directory (lascia vuoto per la directory corrente):"
    MSG_SELECTED_DIR="📂 Directory selezionata"
    MSG_CREATED_DIR="Creata directory"
    MSG_DEPLOYING="Distribuzione agenti"
    MSG_SUMMARY="RIEPILOGO DISTRIBUZIONE"
    MSG_DEPLOYED_TO="Agenti distribuiti in"
    MSG_USE_AGENTS="Per utilizzare questi agenti con Claude Code, assicurati di essere nella directory:"
    MSG_READY="Ora puoi utilizzare gli agenti nelle tue conversazioni con Claude Code!"
    MSG_WELCOME="Benvenuto in MyConvergio - Il tuo partner strategico basato su AI"
    MSG_WELCOME_TITLE="Benvenuto in MyConvergio - Il tuo partner strategico basato su AI"
    MSG_WELCOME_DESC="Questa installazione ti aiuterà a configurare agenti AI specializzati"
    MSG_WELCOME_DESC2="per migliorare la tua esperienza con Claude Code. Puoi installare"
    MSG_WELCOME_DESC3="gli agenti in modo globale (per tutti i progetti) o locale (solo per questo progetto)."
    MSG_CATEGORIES="CATEGORIE DI AGENTI:"
    MSG_AGENT_CATEGORIES="CATEGORIE DI AGENTI:"
    MSG_CAT_LEADERSHIP=" Leadership & Strategia: Processo decisionale strategico e leadership"
    MSG_CAT_TECHNICAL=" Sviluppo Tecnico: Architettura software e implementazione"
    MSG_CAT_BUSINESS=" Operazioni Aziendali: Ottimizzazione dei processi e operazioni"
    MSG_CAT_DESIGN=" Design & UX: Esperienza utente e progettazione dell'interfaccia"
    MSG_CAT_COMPLIANCE=" Conformità & Legale: Considerazioni normative ed etiche"
    MSG_CAT_SPECIALIZED=" Esperti Specializzati: Competenze di nicchia in vari settori"
    MSG_CAT_UTILITY=" Utility di Base: Strumenti essenziali e agenti fondamentali"
    MSG_RECOMMENDED="RACCOMANDATO: Installa tutti gli agenti per un'esperienza MyConvergio completa."
    MSG_NOTE="NOTA: Questo è un progetto sperimentale. Consulta la documentazione per i dettagli."
    MSG_INSTALL_LOCATION="=== POSIZIONE DI INSTALLAZIONE ==="
    MSG_CHOOSE_LOCATION="Scegli dove installare gli agenti:"
    MSG_OPTION_A="A) Tutti i Progetti (Consigliato)"
    MSG_OPTION_A_DESC1="   Installa gli agenti in ~/.claude/agents/"
    MSG_OPTION_A_DESC2="   Disponibile in tutti i tuoi progetti Claude Code"
    MSG_OPTION_A_DESC3="   Ideale per la maggior parte degli utenti che desiderano un accesso a livello di sistema"
    MSG_OPTION_B="B) Solo Questo Progetto"
    MSG_OPTION_B_DESC1="   Installa gli agenti in .claude/agents/ (directory corrente)"
    MSG_OPTION_B_DESC2="   Disponibile solo all'interno di questo progetto specifico"
    MSG_OPTION_B_DESC3="   Utile per personalizzazioni specifiche del progetto"
    MSG_NOTE_LOCATION="Nota: Puoi sempre eseguire nuovamente questo script per modificare l'installazione."
    MSG_CHOOSE_AB="Scegli (A/B):"
    MSG_INVALID_CHOICE="Per favore scegli A o B"
    MSG_AGENT_SELECTION="=== SELEZIONE AGENTI ==="
    MSG_CHOOSE_METHOD="Scegli come selezionare gli agenti da installare:"
    MSG_OPTION_1="1) Tutti gli Agenti (Consigliato)"
    MSG_OPTION_1_DESC1="   Installa tutti i 40+ agenti specializzati"
    MSG_OPTION_1_DESC2="   Fornisce la funzionalità completa di MyConvergio"
    MSG_OPTION_1_DESC3="   Consigliato per la maggior parte degli utenti"
    MSG_OPTION_2="2) Per Categoria"
    MSG_OPTION_2_DESC1="   Seleziona da categorie predefinite di agenti"
    MSG_OPTION_2_DESC2="   Ideale per installare aree funzionali specifiche"
    MSG_OPTION_2_DESC3="   Esempio: Installa solo gli agenti di Sviluppo Tecnico"
    MSG_OPTION_3="3) Selezione Personalizzata"
    MSG_OPTION_3_DESC1="   Scegli manualmente i singoli agenti da installare"
    MSG_OPTION_3_DESC2="   Gli utenti esperti possono creare configurazioni personalizzate"
    MSG_OPTION_3_DESC3="   Utile per installazioni minime o specializzate"
    MSG_TIP_SELECTION="Suggerimento: Puoi sempre eseguire nuovamente questo script per aggiungere o rimuovere agenti."
    MSG_CHOOSE_123="Scegli (1-3):"
    MSG_INSTALLING_AGENTS="Installazione degli agenti in corso..."
    MSG_SUCCESS_INSTALL="SUCCESSO: %d agenti installati in %s"
    MSG_HOW_TO_USE="COME UTILIZZARE:"
    MSG_STEP_1="1. Apri Claude Code"
    MSG_STEP_2="2. Digita @ per vedere i tuoi agenti"
    MSG_STEP_3="3. Esempio: @ali-chief-of-staff Aiutami a pianificare questo progetto"
else
    AGENTS_DIR="$SCRIPT_DIR/claude-agents"
    MSG_LANG="English"
    MSG_DEPLOY="MyConvergio Agents Deployment"
    MSG_SELECT_DIR="Select destination directory"
    MSG_ENTER_DIR="Enter destination directory (leave empty for current directory):"
    MSG_SELECTED_DIR="📂 Selected directory"
    MSG_CREATED_DIR="Created directory"
    MSG_DEPLOYING="Deploying agents"
    MSG_SUMMARY="DEPLOYMENT SUMMARY"
    MSG_DEPLOYED_TO="Agents have been deployed to"
    MSG_USE_AGENTS="To use these agents with Claude Code, ensure you're in the directory:"
    MSG_READY="You can now use the agents in your Claude Code conversations!"
    MSG_WELCOME="Welcome to MyConvergio - Your AI-Powered Strategic Partner"
    MSG_INSTALL_HELP="This installation will help you set up specialized AI agents to enhance\nyour Claude Code experience. You can install agents globally (all projects)\nor locally (this project only)."
    MSG_CATEGORIES="AGENT CATEGORIES:"
    MSG_CAT_LEADERSHIP=" Leadership & Strategy: Strategic decision-making and leadership"
    MSG_CAT_TECHNICAL=" Technical Development: Software architecture and implementation"
    MSG_CAT_BUSINESS=" Business Operations: Process optimization and operations"
    MSG_CAT_DESIGN=" Design & UX: User experience and interface design"
    MSG_CAT_COMPLIANCE=" Compliance & Legal: Regulatory and ethical considerations"
    MSG_CAT_SPECIALIZED=" Specialized Experts: Niche expertise across domains"
    MSG_CAT_UTILITY=" Core Utilities: Essential tools and foundational agents"
    MSG_RECOMMENDED="RECOMMENDED: Install all agents for the full MyConvergio experience."
    MSG_NOTE="NOTE: This is an experimental project. See documentation for details."
    MSG_INSTALL_LOCATION="=== INSTALLATION LOCATION ==="
    MSG_CHOOSE_LOCATION="Choose where to install the agents:"
    MSG_OPTION_A="A) All Projects (Recommended)"
    MSG_OPTION_A_DESC1="   Installs agents in ~/.claude/agents/"
    MSG_OPTION_A_DESC2="   Available across all your Claude Code projects"
    MSG_OPTION_A_DESC3="   Best for most users who want system-wide access"
    MSG_OPTION_B="B) This Project Only"
    MSG_OPTION_B_DESC1="   Installs agents in .claude/agents/ (current directory)"
    MSG_OPTION_B_DESC2="   Only available within this specific project"
    MSG_OPTION_B_DESC3="   Useful for project-specific agent customizations"
    MSG_NOTE_LOCATION="Note: You can always run this script again to modify your installation."
    MSG_CHOOSE_AB="Choose (A/B):"
    MSG_INVALID_CHOICE="Please choose A or B"
    MSG_AGENT_SELECTION="=== AGENT SELECTION ==="
    MSG_CHOOSE_METHOD="Choose how to select agents for installation:"
    MSG_OPTION_1="1) All Agents (Recommended)"
    MSG_OPTION_1_DESC1="   Installs all 40+ specialized agents"
    MSG_OPTION_1_DESC2="   Provides complete MyConvergio functionality"
    MSG_OPTION_1_DESC3="   Recommended for most users"
    MSG_OPTION_2="2) By Category"
    MSG_OPTION_2_DESC1="   Select from predefined agent categories"
    MSG_OPTION_2_DESC2="   Good for installing specific functional areas"
    MSG_OPTION_2_DESC3="   Example: Install only Technical Development agents"
    MSG_OPTION_3="3) Custom Selection"
    MSG_OPTION_3_DESC1="   Hand-pick individual agents to install"
    MSG_OPTION_3_DESC2="   Advanced users can create custom configurations"
    MSG_OPTION_3_DESC3="   Useful for minimal or specialized deployments"
    MSG_TIP_SELECTION="Tip: You can always run this script again to add or remove agents."
    MSG_CHOOSE_123="Choose (1-3):"
    MSG_INSTALLING_AGENTS="Installing agents..."
    MSG_SUCCESS_INSTALL="SUCCESS: %d agents installed to %s"
    MSG_HOW_TO_USE="HOW TO USE:"
    MSG_STEP_1="1. Open Claude Code"
    MSG_STEP_2="2. Type @ to see your agents"
    MSG_STEP_3="3. Example: @ali-chief-of-staff Help me plan this project"
fi

# Default destination directory (can be overridden by user)
DEST_DIR="${1:-.}"

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
    " Leadership & Strategy: Strategic decision-making, executive leadership, and organizational vision"
    " Technical Development: Software architecture, coding, and technical implementation experts"
    " Business Operations: Process optimization, operations, and business excellence"
    " Design & UX: User experience, interface design, and creative direction"
    " Compliance & Legal: Regulatory compliance, legal considerations, and ethical guidelines"
    " Specialized Experts: Niche expertise across various domains and industries"
    " Core Utilities: Foundational agents and essential tools for the ecosystem"
)

# Helper functions for colored output
print_error() { echo -e "${RED} ERROR:${NC} $1"; }
print_success() { echo -e "${GREEN} SUCCESS:${NC} $1"; }
print_info() { echo -e "${BLUE} INFO:${NC} $1"; }
print_warning() { echo -e "${YELLOW} WARNING:${NC} $1"; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
print_subheader() { echo -e "\n${BLUE} $1${NC}"; }

# Function to select directory using fzf if available, or simple menu if not
select_directory() {
    if [[ -n "$DEST_DIR" && "$DEST_DIR" != "." ]]; then
        # Use provided directory
        if [[ ! -d "$DEST_DIR" ]]; then
            read -p "Directory '$DEST_DIR' does not exist. Create it? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p "$DEST_DIR" || {
                    print_error "Failed to create directory: $DEST_DIR"
                    exit 1
                }
            else
                print_error "Aborting: Directory does not exist and was not created"
                exit 1
            fi
        fi
        DEST_DIR="$(cd "$DEST_DIR" && pwd)"
        return 0
    fi

    if [[ "$SELECT_DIR" == true ]]; then
        if command -v fzf &> /dev/null; then
            # Use fzf for interactive directory selection
            echo -e "\n${BLUE} $MSG_SELECT_DIR (CTRL+C to cancel):${NC}"
            DEST_DIR="$(find ~/ -type d 2>/dev/null | fzf --height 40% --reverse --preview 'ls -la {}')"
            
            if [[ -z "$DEST_DIR" ]]; then
                print_warning "No directory selected. Using current directory."
                DEST_DIR="."
            fi
        else
            # Fallback to simple directory input
            echo -e "\n${BLUE} $MSG_ENTER_DIR${NC}"
            read -r -p "> " DEST_DIR
            DEST_DIR="${DEST_DIR:-.}"
        fi
    else
        DEST_DIR="."
    fi
    
    # Expand tilde and resolve to absolute path
    DEST_DIR="$(cd "$DEST_DIR" && pwd)"
    echo -e "\n${GREEN} $MSG_SELECTED_DIR: $DEST_DIR${NC}"
}

# Check prerequisites and versions
check_prerequisites() {
    if [ ! -d "$AGENTS_DIR" ]; then
        print_error "Agents directory not found: $AGENTS_DIR"
        exit 1
    fi
    
    # Ensure destination directory exists and is accessible
    if [ ! -d "$DEST_DIR" ]; then
        read -p "Directory '$DEST_DIR' does not exist. Create it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$DEST_DIR" || {
                print_error "Failed to create directory: $DEST_DIR"
                exit 1
            }
        else
            print_error "Aborting: Directory does not exist and was not created"
            exit 1
        fi
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
    
    print_header "$MSG_DEPLOY"
    
    # Let user select destination directory
    # Print header
    clear
    echo ""
    echo -e " ${BLUE}${MSG_DEPLOY}${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..${#MSG_DEPLOY}})${NC}"
    echo ""
    echo -e "${YELLOW}${MSG_WELCOME}${NC}"
    echo ""
    echo -e "${MSG_INSTALL_HELP}"
    echo -e "${MSG_INSTALL_HELP2}"
    echo -e "${MSG_INSTALL_HELP3}"
    echo ""
    echo -e "${BLUE}${MSG_CATEGORIES}${NC}"
    echo -e "${MSG_CAT_LEADERSHIP}"
    echo -e "${MSG_CAT_TECHNICAL}"
    echo -e "${MSG_CAT_BUSINESS}"
    echo -e "${MSG_CAT_DESIGN}"
    echo -e "${MSG_CAT_COMPLIANCE}"
    echo -e "${MSG_CAT_SPECIALIZED}"
    echo -e "${MSG_CAT_UTILITY}"
    echo ""
    echo -e "${YELLOW}${MSG_RECOMMENDED}${NC}"
    echo ""
    echo -e "${BLUE}${MSG_NOTE}${NC}"
    
    # Print summary
    print_header "${MSG_SUMMARY}"
    echo -e "${MSG_DEPLOYED_TO}: ${YELLOW}$DEST_DIR${NC}"
    echo -e "\n${MSG_USE_AGENTS}\n  ${YELLOW}$DEST_DIR${NC}"
    echo -e "\n${GREEN}${MSG_READY}${NC}"
    
    # WHERE TO INSTALL
    print_header "${MSG_INSTALL_LOCATION}"
    echo -e "${MSG_CHOOSE_LOCATION}"
    echo ""
    echo -e "${YELLOW}${MSG_OPTION_A}${NC}"
    echo -e "   ${MSG_OPTION_A_DESC1}"
    echo -e "   ${MSG_OPTION_A_DESC2}"
    echo -e "   ${MSG_OPTION_A_DESC3}"
    echo ""
    echo -e "${YELLOW}${MSG_OPTION_B}${NC}"
    echo -e "   ${MSG_OPTION_B_DESC1}"
    echo -e "   ${MSG_OPTION_B_DESC2}"
    echo -e "   ${MSG_OPTION_B_DESC3}"
    echo ""
    echo -e "${BLUE}${MSG_NOTE}:${NC} ${MSG_NOTE_LOCATION}"
    
    local where=""
    while true; do
        read -p "${MSG_CHOOSE_AB} " choice
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
            echo "$((i+1)). ${CATEGORY_DESCRIPTIONS[$i]}"
        done
        
        echo ""
        echo "Enter the numbers of the categories you want to install, separated by commas (e.g., 1,3,5):"
        read -p "> " selected_categories
        
        # Process selected categories
        IFS=',' read -ra category_nums <<< "$selected_categories"
        for num in "${category_nums[@]}"; do
            # Remove any whitespace
            num=$(echo "$num" | tr -d ' ')
            
            # Validate input
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#CATEGORIES[@]} ]; then
                selected_agents+=("${CATEGORIES[$((num-1))]}")
            fi
        done
        
        if [ ${#selected_agents[@]} -eq 0 ]; then
            print_warning "No valid categories selected. Installing all agents."
            selected_agents=("${CATEGORIES[@]}")
        fi
    else
        # Install all agents
        selected_agents=("${CATEGORIES[@]}")
    fi
    
    # Determine where to install the agents
    if [ "$where" = "global" ]; then
        # Global installation (for all projects)
        target_dir="$HOME/.claude-code/agents"
        DEPLOY_DIR="$target_dir"
    else
        # Local installation (for current project only)
        target_dir=".claude/agents"
        DEPLOY_DIR="$target_dir"
    fi
    
    # Create the directory if it doesn't exist
    if [[ ! -d "$DEPLOY_DIR" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would create directory: $DEPLOY_DIR"
        else
            mkdir -p "$DEPLOY_DIR"
            print_success "$MSG_CREATED_DIR: $DEPLOY_DIR"
        fi
    fi
    
    # Deploy selected agents
    count=0
    for category in "${selected_agents[@]}"; do
        if [ -d "$AGENTS_DIR/$category" ]; then
            # Create category directory if it doesn't exist
            if [[ ! -d "$DEPLOY_DIR/$category" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    print_info "[DRY-RUN] Would create directory: $DEPLOY_DIR/$category"
                else
                    mkdir -p "$DEPLOY_DIR/$category"
                fi
            fi
            
            # Copy agent files
            for agent in "$AGENTS_DIR/$category/"*.md; do
                if [ -f "$agent" ]; then
                    agent_name=$(basename "$agent")
                    count=$((count + 1))
                    
                    if [[ "$DRY_RUN" == true ]]; then
                        print_info "[DRY-RUN] Would copy: $agent_name to $DEPLOY_DIR/$category/"
                    else
                        cp "$agent" "$DEPLOY_DIR/$category/"
                        print_success "Deployed: $category/$agent_name"
                    fi
                fi
            done
        fi
    done
                    
    # Print summary
    print_header "$MSG_SUMMARY"
    echo "$MSG_DEPLOYED_TO: $DEPLOY_DIR"
    echo -e "\n$MSG_USE_AGENTS\n  ${YELLOW}$DEST_DIR${NC}"
    echo -e "\n$MSG_READY"
    
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
