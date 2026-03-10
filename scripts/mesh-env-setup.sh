#!/usr/bin/env bash
# mesh-env-setup.sh — Full environment replication for the Claude mesh
# Version: 1.0.0
# Usage: mesh-env-setup.sh [--tools-only] [--hooks-only] [--full] [--check]
#
# --full (default): all 7 steps
# --tools-only:     step 1 only (CLI tools)
# --hooks-only:     step 4 only (hooks + settings.json)
# --check:          verify installed components, print table, exit 0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

source "$SCRIPT_DIR/lib/mesh-env-tools.sh"

# ---- argument parsing --------------------------------------------------------
MODE="full"
for arg in "$@"; do
	case "$arg" in
	--full) MODE="full" ;;
	--tools-only) MODE="tools" ;;
	--hooks-only) MODE="hooks" ;;
	--check) MODE="check" ;;
	--help | -h)
		sed -n '/^# Usage/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# //'
		exit 0
		;;
	*)
		echo "Unknown option: $arg" >&2
		echo "Usage: $(basename "$0") [--full|--tools-only|--hooks-only|--check]" >&2
		exit 1
		;;
	esac
done

# ---- step 1: CLI tools -------------------------------------------------------
step_tools() {
	_log "Step 1: Installing CLI tools..."
	install_tools
}

# ---- step 2: AI engines (interactive) ----------------------------------------
step_ai_engines() {
	_log "Step 2: AI engine setup..."
	install_ai_engines
}

# ---- step 3: initialize ~/.claude/data/ and dashboard.db --------------------
step_init_db() {
	_log "Step 3: Initializing $CLAUDE_HOME/data/..."
	mkdir -p "$CLAUDE_HOME/data"
	local db="$CLAUDE_HOME/data/dashboard.db"
	if [[ ! -f "$db" ]]; then
		local init_sql="$SCRIPT_DIR/init-db.sql"
		if [[ -f "$init_sql" ]]; then
			sqlite3 "$db" <"$init_sql"
			_ok "dashboard.db created from init-db.sql"
		else
			sqlite3 "$db" "SELECT 1;" &>/dev/null
			_ok "dashboard.db created (empty)"
		fi
	else
		_ok "dashboard.db already exists (skipping)"
	fi
}

# ---- step 4: hooks + settings.json ------------------------------------------
step_hooks() {
	_log "Step 4: Configuring hooks..."
	local local_hooks="$PWD/.claude/hooks"
	local src_hooks="$CLAUDE_HOME/hooks"

	# Copy hooks dir if target is a local .claude/hooks
	if [[ -d "$src_hooks" && ! -d "$local_hooks" ]]; then
		mkdir -p "$(dirname "$local_hooks")"
		cp -r "$src_hooks" "$local_hooks"
		_ok "Copied $src_hooks → $local_hooks"
	elif [[ -d "$local_hooks" ]]; then
		_ok "Local hooks already present (skipping)"
	else
		_warn "No source hooks dir at $src_hooks"
	fi

	# Symlink settings.json if not present
	local local_settings="$PWD/.claude/settings.json"
	local src_settings="$CLAUDE_HOME/settings.json"
	if [[ ! -f "$local_settings" && ! -L "$local_settings" ]]; then
		if [[ -f "$src_settings" ]]; then
			mkdir -p "$(dirname "$local_settings")"
			ln -s "$src_settings" "$local_settings"
			_ok "Symlinked settings.json"
		else
			_warn "No settings.json at $src_settings — skipping symlink"
		fi
	else
		_ok "settings.json already present (skipping)"
	fi
}

# ---- step 5: shell PATH export -----------------------------------------------
step_shell_path() {
	_log "Step 5: Adding $CLAUDE_HOME/scripts to PATH..."
	local path_export="export PATH=\"\$HOME/.claude/scripts:\$PATH\""
	local rc_files=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
	local added=false

	for rc in "${rc_files[@]}"; do
		if [[ -f "$rc" ]] && ! grep -qF 'claude/scripts' "$rc" 2>/dev/null; then
			echo "" >>"$rc"
			echo "# Added by mesh-env-setup.sh" >>"$rc"
			echo "$path_export" >>"$rc"
			_ok "PATH export added to $rc"
			added=true
		elif [[ -f "$rc" ]]; then
			_ok "$rc already has claude/scripts in PATH"
			added=true
		fi
	done

	[[ "$added" == "false" ]] && _warn "No shell rc files found — add manually: $path_export"
}

# ---- step 6: shell aliases ---------------------------------------------------
step_aliases() {
	_log "Step 6: Configuring shell aliases..."
	local aliases_src="$CLAUDE_HOME/shell-aliases.sh"
	local source_line="[[ -f \"$CLAUDE_HOME/shell-aliases.sh\" ]] && source \"$CLAUDE_HOME/shell-aliases.sh\""
	local rc_files=("$HOME/.zshrc" "$HOME/.bashrc")

	if [[ ! -f "$aliases_src" ]]; then
		_warn "shell-aliases.sh not found at $aliases_src — skipping"
		return 0
	fi

	for rc in "${rc_files[@]}"; do
		if [[ -f "$rc" ]] && ! grep -qF 'shell-aliases.sh' "$rc" 2>/dev/null; then
			echo "" >>"$rc"
			echo "# Added by mesh-env-setup.sh" >>"$rc"
			echo "$source_line" >>"$rc"
			_ok "shell-aliases.sh sourced from $rc"
		elif [[ -f "$rc" ]]; then
			_ok "$rc already sources shell-aliases.sh"
		fi
	done
}

# ---- step 7: persistent tmux session (convergio) ----------------------------
step_persistent_tmux() {
	_log "Step 7: Configuring persistent Convergio tmux session..."
	local snippet='# auto-tmux-attach: persistent Convergio session for SSH connections
if [[ -n "$SSH_CONNECTION" && -z "$TMUX" && $- == *i* ]]; then
  exec tmux new-session -As convergio
fi'
	local rc_files=("$HOME/.zshrc" "$HOME/.bashrc")
	local added=false

	for rc in "${rc_files[@]}"; do
		if [[ -f "$rc" ]] && ! grep -q 'auto-tmux-attach' "$rc" 2>/dev/null; then
			printf '\n%s\n' "$snippet" >>"$rc"
			_ok "Persistent tmux session added to $rc"
			added=true
		elif [[ -f "$rc" ]]; then
			_ok "$rc already has auto-tmux-attach"
			added=true
		fi
	done

	[[ "$added" == "false" ]] && _warn "No shell rc files found — add auto-tmux-attach manually"
}

# ---- step 8: verify ----------------------------------------------------------
step_verify() {
	_log "Step 8: Verification table"
	print_check_table
}

# ---- dispatch ----------------------------------------------------------------
case "$MODE" in
check)
	print_check_table
	exit 0
	;;
tools)
	step_tools
	;;
hooks)
	step_hooks
	;;
full)
	step_tools
	step_ai_engines
	step_init_db
	step_hooks
	step_shell_path
	step_aliases
	step_persistent_tmux
	step_verify
	;;
esac

_log "Done."
