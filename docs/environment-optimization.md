# Claude Environment Optimization

> Ottimizzato per: parallelizzazione, velocità, affidabilità, context tokens

## Tool Stack

| Tool | Sostituisce | Vantaggio |
|------|-------------|-----------|
| fd | find | 5x faster, .gitignore aware |
| rg | grep | 10x faster, parallel |
| bat | cat | syntax highlight, git integration |
| eza | ls | icons, git status, tree view |
| fzf | - | fuzzy finder interattivo |
| jq | - | JSON parsing |
| delta | diff | git diff colorato |
| zoxide | cd | navigazione smart frecency |
| dust | du | disk usage visuale |
| btop | top/htop | system monitor moderno |

## Formatters

| Tool | Linguaggio |
|------|------------|
| prettier | JS/TS/CSS/MD/JSON |
| shfmt | Shell scripts |
| black | Python |

## Repo Knowledge Tools

| Tool | Uso |
|------|-----|
| tokei | Statistiche codice |
| onefetch | Repo summary |
| ast-grep | Semantic code search |
| universal-ctags | Symbol indexing |
| hyperfine | Benchmarking |
| tlrc | Man pages semplificate |

## Hooks Attivi

### PreToolUse
- **warn-bash-antipatterns.sh**: Avvisa se uso find/grep/cat in bash

### PostToolUse
- **enforce-line-limit.sh**: Blocca file >250 righe
- **auto-format.sh**: Formatta automaticamente dopo Write

### Stop
- **session-end-tokens.sh**: Traccia token a fine sessione

## Settings Ottimizzati

```json
{
  "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
  "MAX_THINKING_TOKENS": "31999",
  "BASH_DEFAULT_TIMEOUT_MS": "60000",
  "NODE_OPTIONS": "--max-old-space-size=16384",
  "UV_THREADPOOL_SIZE": "12"
}
```

## Regole Context-Saving

1. **Tool dedicati** > bash commands (Glob, Grep, Read, Edit, Write)
2. **Task agent** per ricerche open-ended (risparmia context)
3. **Parallel tool calls** quando indipendenti
4. **Max 250 righe/file** per leggibilità

## Setup Shell

Aggiungi a `~/.zshrc`:
```bash
source ~/.claude/shell-aliases.sh
eval "$(zoxide init zsh)"
```

## Struttura Directory

```
~/.claude/
├── CLAUDE.md           # Istruzioni principali
├── settings.json       # Configurazione Claude Code
├── hooks/              # Hook automatici
│   ├── enforce-line-limit.sh
│   ├── auto-format.sh
│   ├── warn-bash-antipatterns.sh
│   └── session-end-tokens.sh
├── scripts/            # Utility scripts
│   ├── plan-db.sh
│   └── install-missing-tools.sh
├── rules/              # Regole engineering
├── agents/             # Agent definitions
├── skills/             # Skill definitions
└── docs/               # Documentazione
```

## Repo Indexing (per migliorare conoscenza Claude)

```bash
# Genera context file per un repo
~/.claude/scripts/repo-index.sh

# Output in .claude/:
#   repo-info.md     - overview, linguaggi, struttura
#   symbols.txt      - indice funzioni/classi (ctags)
#   entry-points.md  - main files, config, test dirs
#   api-patterns.md  - route definitions, endpoints
#   dependencies.md  - npm/pip/cargo deps

# Funzioni shell (dopo source shell-aliases.sh)
repo-info   # Quick summary con onefetch + tokei
repo-index  # Genera .claude-context file
```

## Manutenzione

```bash
# Aggiorna tutti i tool
brew upgrade fd rg bat eza fzf delta zoxide prettier shfmt tokei hyperfine tlrc onefetch ast-grep universal-ctags

# Verifica versioni
~/.claude/scripts/install-missing-tools.sh
```
