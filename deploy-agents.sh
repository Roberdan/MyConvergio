#!/bin/bash

# MyConvergio Agent Deployment Script - VERSIONE SEMPLICE E CHIARA
set -e

# Parse command line arguments
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🧪 MODALITÀ DRY-RUN: Simulazione senza modifiche"
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
    echo -e "${RED}❌ ERRORE:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESSO:${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️ INFO:${NC} $1"
}

# Verifica prerequisiti
check_prerequisites() {
    if [ ! -d "$AGENTS_DIR" ]; then
        print_error "Directory agenti non trovata: $AGENTS_DIR"
        exit 1
    fi
    
    local agent_count=$(find "$AGENTS_DIR" -name "*.md" -type f | wc -l)
    if [ "$agent_count" -lt 22 ]; then
        print_error "Trovati solo $agent_count agenti su 22 attesi in $AGENTS_DIR"
        exit 1
    fi
    
    print_success "Prerequisiti verificati: $agent_count agenti pronti per l'installazione"
}

# Funzione principale
main() {
    clear
    
    # Verifica prerequisiti
    check_prerequisites
    
    echo "🚀 INSTALLAZIONE AGENTI MYCONVERGIO"
    echo "===================================="
    echo ""
    echo "COSA FA QUESTO SCRIPT:"
    echo "• Installa 22 agenti AI specializzati per Claude Code"
    echo "• Ti aiutano con strategia, creatività, OKR, comunicazione, etc."
    echo "• Li usi scrivendo @chief-of-staff o @creative-director"
    echo ""
    echo "GLI AGENTI SONO (tutti con colori personalizzati):"
    echo "👑 ali-chief-of-staff (Ali - orchestratore principale) 🔵"
    echo "🎯 satya-board-of-directors (Satya) 🟣, matteo-strategic-business-architect (Matteo) 🟢, domik-mckinsey-strategic-decision-maker (Domik - McKinsey Partner) 🟢, antonio-okr-strategy-expert (Antonio) 🔴"
    echo "⚡ luke-program-management-excellence-coach (Luke) 🔵, enrico-process-optimization-consultant (Enrico) 🟠, ami-financial-roi-analyst (Ami - CFO) 🟢"
    echo "🎨 jony-creative-director (Jony) 🟡, stefano-design-thinking-facilitator (Stefano) 🟡, coach-team-dynamics-cross-cultural-expert (Coach) 🟢"
    echo "🌍 dave-change-management-specialist (Dave) 🟣, behice-global-culture-intelligence-expert (Behice) 🟠"
    echo "🔧 baccio-technology-architecture-advisor (Baccio) ⚫, thor-quality-assurance-guardian (Thor) 🟣, steve-executive-communication-strategist (Steve) ⚪"
    echo "♿ jenny-inclusive-accessibility-champion (Jenny - esperto accessibilità) 🟣"
    echo "✨ po-prompt-optimizer (Po - ottimizzazione magica prompt AI) 🟠"
    echo "🚀 sam-startupper (Sam - startup founder Y Combinator style) 🔴"
    echo "📋 taskmaster-strategic-task-decomposition-master (Taskmaster - task breakdown) ⚪"
    echo "👨‍💻 dan-engineering-gm (Dan - GM Software Engineering Microsoft style) 🟢"
    echo "🔍 ava-analytics-insights-virtuoso (Ava - ecosystem intelligence detective) 🟣"
    echo ""
    
    # PRIMA DOMANDA - DOVE INSTALLARE
    echo "═══════════════════════════════════════════════════════════════════"
    echo "DOMANDA 1: DOVE LI INSTALLO?"
    echo ""
    echo "OPZIONE A = IN TUTTI I TUOI PROGETTI CLAUDE CODE"
    echo "• Gli agenti funzionano ovunque apri Claude Code"
    echo "• Si installano in ~/.claude/agents/"
    echo "• Consigliato se usi Claude Code per più progetti"
    echo ""
    echo "OPZIONE B = SOLO IN QUESTO PROGETTO"
    echo "• Gli agenti funzionano solo in questa cartella"
    echo "• Si installano in .claude/agents/"
    echo "• Utile se vuoi testarli o usarli solo qui"
    echo ""
    
    local where=""
    while true; do
        echo "DOVE LI INSTALLO?"
        read -p "Scrivi A (tutti i progetti) o B (solo qui): " choice
        case $choice in
            [Aa])
                where="global"
                echo "✅ Installazione in TUTTI I PROGETTI (~/.claude/agents/)"
                break
                ;;
            [Bb])
                where="local"
                echo "✅ Installazione SOLO QUI (.claude/agents/)"
                break
                ;;
            *)
                echo "❌ Scrivi 'A' per tutti i progetti o 'B' per solo qui"
                echo ""
                ;;
        esac
    done
    
    echo ""
    
    # SECONDA DOMANDA - QUANTI AGENTI
    echo "═══════════════════════════════════════════════════════════════════"
    echo "DOMANDA 2: QUANTI AGENTI INSTALLO?"
    echo ""
    echo "OPZIONE 1 = TUTTI I 22 AGENTI"
    echo "• Suite completa MyConvergio"
    echo "• Installazione in 30 secondi"
    echo "• Consigliato per avere tutto pronto"
    echo ""
    echo "OPZIONE 2 = SOLO ALCUNI AGENTI"
    echo "• Scegli tu quali installare"
    echo "• Installazione più leggera"
    echo "• Puoi aggiungerne altri dopo"
    echo ""
    
    local agents=""
    while true; do
        echo "QUANTI AGENTI INSTALLO?"
        read -p "Scrivi 1 (tutti) o 2 (alcuni): " choice
        case $choice in
            1)
                agents="all"
                echo "✅ Installerò TUTTI I 22 AGENTI"
                break
                ;;
            2)
                echo ""
                echo "AGENTI DISPONIBILI:"
                echo "ali-chief-of-staff, satya-board-of-directors, matteo-strategic-business-architect,"
                echo "domik-mckinsey-strategic-decision-maker, taskmaster-strategic-task-decomposition-master,"
                echo "antonio-okr-strategy-expert, luke-program-management-excellence-coach,"
                echo "enrico-process-optimization-consultant, ami-financial-roi-analyst, jony-creative-director,"
                echo "stefano-design-thinking-facilitator, coach-team-dynamics-cross-cultural-expert,"
                echo "dave-change-management-specialist, behice-global-culture-intelligence-expert,"
                echo "baccio-technology-architecture-advisor, thor-quality-assurance-guardian,"
                echo "steve-executive-communication-strategist, jenny-inclusive-accessibility-champion,"
                echo "po-prompt-optimizer, sam-startupper, dan-engineering-gm, ava-analytics-insights-virtuoso"
                echo ""
                read -p "Scrivi i nomi degli agenti separati da virgole: " agents
                echo "✅ Installerò gli agenti: $agents"
                break
                ;;
            *)
                echo "❌ Scrivi '1' per tutti o '2' per alcuni"
                echo ""
                ;;
        esac
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "INSTALLAZIONE IN CORSO..."
    echo ""
    
    # Determina directory target
    if [ "$where" = "global" ]; then
        target_dir="$HOME/.claude/agents"
    else
        target_dir=".claude/agents"
    fi
    
    # Crea directory se non esiste
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Createrei directory: $target_dir"
    else
        mkdir -p "$target_dir"
    fi
    
    # PULIZIA: Elimina tutti i vecchi agenti prima di installare i nuovi
    print_info "Pulizia agenti esistenti..."
    if [ -d "$target_dir" ]; then
        local old_agents=$(find "$target_dir" -name "*.md" -type f | wc -l)
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY-RUN] Rimuoverei $old_agents vecchi agenti da $target_dir"
        else
            # Rimuove solo i file .md (agenti) dalla directory target
            find "$target_dir" -name "*.md" -type f -delete 2>/dev/null || true
            print_success "Vecchi agenti rimossi da $target_dir"
        fi
    fi
    
    # Installa agenti
    local count=0
    if [ "$agents" = "all" ]; then
        for agent_file in "$AGENTS_DIR"/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file" .md)
                if [ "$DRY_RUN" = true ]; then
                    echo "✅ [DRY-RUN] Installerei: $agent_name"
                else
                    cp "$agent_file" "$target_dir/"
                    echo "✅ Installato: $agent_name"
                fi
                count=$((count + 1))
            fi
        done
    else
        IFS=',' read -ra AGENT_ARRAY <<< "$agents"
        for agent_name in "${AGENT_ARRAY[@]}"; do
            agent_name=$(echo "$agent_name" | xargs)  # rimuove spazi
            agent_file="$AGENTS_DIR/${agent_name}.md"
            if [ -f "$agent_file" ]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "✅ [DRY-RUN] Installerei: $agent_name"
                else
                    cp "$agent_file" "$target_dir/"
                    echo "✅ Installato: $agent_name"
                fi
                count=$((count + 1))
            else
                echo "❌ Non trovato: $agent_name"
            fi
        done
    fi
    
    echo ""
    echo "🎉 INSTALLAZIONE COMPLETATA!"
    echo "=============================="
    print_success "$count agenti installati in $target_dir"
    
    # Verifica post-installazione
    echo ""
    print_info "Verifica installazione..."
    local installed_count=$(find "$target_dir" -name "*.md" -type f | wc -l)
    if [ "$installed_count" -eq "$count" ]; then
        print_success "Verifica completata: tutti gli agenti sono installati correttamente"
    else
        print_error "Possibile problema: trovati $installed_count file ma attesi $count"
    fi
    echo ""
    echo "COME USARLI:"
    echo "1. Apri Claude Code"
    echo "2. Scrivi @ e vedrai i tuoi agenti"
    echo "3. Prova: @ali-chief-of-staff Ali, aiutami a pianificare il progetto"
    echo ""
    echo "ESEMPI:"
    echo "@jony-creative-director Jony, serve un nome innovativo per il nostro prodotto"
    echo "@antonio-okr-strategy-expert Antonio, crea OKR per il nostro team Q4"
    echo "@behice-global-culture-intelligence-expert Behice, spiegami la cultura business giapponese"
    echo "@po-prompt-optimizer Po, ottimizza questo prompt per Claude Sonnet 4"
    echo "@sam-startupper Sam, aiutami a creare un pitch deck per la mia startup"
    echo "@dan-engineering-gm Dan, strategia di engineering per scalare da 10 a 100 sviluppatori"
    echo ""
    echo "🔥 Ali (Chief of Staff) coordina automaticamente tutti gli altri agenti!"
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo "📝 NOTA: Questa era una simulazione. Per installare davvero rilanciare senza --dry-run"
    else
        echo "💡 SUGGERIMENTO: Per testare senza installare usa: ./deploy-agents.sh --dry-run"
    fi
}

# Esegui se lanciato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi