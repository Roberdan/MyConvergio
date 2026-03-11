#!/usr/bin/env bash
# scripts/shell-aliases.sh — Shell aliases for claude-core ecosystem
# Version: 2.0.0

# === Config sync ===
alias psync='~/.claude/scripts/peer-sync.sh'
alias csync='~/.claude/scripts/sync-claude-config.sh'
alias dbsync='~/.claude/scripts/sync-dashboard-db.sh'
alias bg='buongiorno'

# === Rust daemon/server ===
alias ccore='claude-core'
alias cserve='claude-core serve'
alias cdaemon='claude-core daemon'

[[ -f "$HOME/.claude/shell-aliases.sh" ]] && source "$HOME/.claude/shell-aliases.sh"
