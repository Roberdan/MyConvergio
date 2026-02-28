#!/usr/bin/env bash
# remote-repo-sync.sh - Sync repos and check CLI versions on omarchy
# Runs ON the Linux machine (copied via scp, executed via ssh)
# Version: 1.0.0
set -euo pipefail

# --- Output helpers ---
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'
info() { echo -e "${C}[repo-sync]${N} $*"; }
ok() { echo -e "${G}[repo-sync]${N} $*"; }
warn() { echo -e "${Y}[repo-sync]${N} $*"; }
err() { echo -e "${R}[repo-sync]${N} $*" >&2; }

GITHUB_DIR="$HOME/GitHub"
mkdir -p "$GITHUB_DIR"

# --- Repo definitions ---
# Format: name|url|branch
REPOS=(
	"MirrorBuddy|https://github.com/FightTheStroke/MirrorBuddy.git|main"
	"VirtualBPM|https://github.com/roberdan_microsoft/VirtualBPM.git|main"
	"MyConvergio|https://github.com/Roberdan/MyConvergio.git|master"
	"Convergio|https://github.com/Roberdan/Convergio.git|master"
)

# --- Sync each repo ---
info "Syncing ${#REPOS[@]} repositories..."
echo ""

for entry in "${REPOS[@]}"; do
	IFS='|' read -r name url branch <<<"$entry"
	local_path="$GITHUB_DIR/$name"

	if [[ ! -d "$local_path" ]]; then
		info "$name: cloning..."
		if git clone "$url" "$local_path" 2>/dev/null; then
			ok "$name: cloned"
		else
			warn "$name: clone FAILED (check access)"
			continue
		fi
	fi

	cd "$local_path"
	git fetch origin 2>/dev/null || {
		warn "$name: fetch failed"
		continue
	}

	local_hash=$(git rev-parse HEAD 2>/dev/null)
	remote_hash=$(git rev-parse "origin/$branch" 2>/dev/null || echo "unknown")

	if [[ "$local_hash" == "$remote_hash" ]]; then
		ok "$name: up to date (${local_hash:0:7})"
	else
		if git pull origin "$branch" --ff-only 2>/dev/null; then
			new_hash=$(git rev-parse HEAD)
			ok "$name: updated ${local_hash:0:7} -> ${new_hash:0:7}"
		else
			warn "$name: pull failed (diverged? manual merge needed)"
		fi
	fi
done

# --- CLI version checks ---
echo ""
info "CLI versions:"

if command -v claude &>/dev/null; then
	claude_ver=$(claude --version 2>/dev/null || echo "unknown")
	ok "  claude: $claude_ver"
else
	warn "  claude: not installed"
fi

if command -v gh &>/dev/null; then
	if gh copilot --version &>/dev/null 2>&1; then
		copilot_ver=$(gh copilot --version 2>/dev/null || echo "unknown")
		ok "  gh copilot: $copilot_ver"
	else
		warn "  gh copilot: not installed (gh extension install github/gh-copilot)"
	fi
else
	warn "  gh: not installed"
fi

# --- Copilot sync (if available) ---
if command -v copilot-sync.sh &>/dev/null; then
	info "Running copilot-sync..."
	copilot-sync.sh sync 2>/dev/null || warn "copilot-sync failed"
elif [[ -x "$HOME/.claude/scripts/copilot-sync.sh" ]]; then
	info "Running copilot-sync..."
	"$HOME/.claude/scripts/copilot-sync.sh" sync 2>/dev/null || warn "copilot-sync failed"
fi

echo ""
ok "Repo sync complete!"
