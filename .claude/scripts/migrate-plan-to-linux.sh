#!/usr/bin/env bash
# migrate-plan-to-linux.sh - Migrate a plan worktree from Mac to Linux
# Usage: migrate-plan-to-linux.sh <plan_id>
# Version: 1.0.0
set -euo pipefail

PLAN_ID="${1:?Usage: migrate-plan-to-linux.sh <plan_id>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Output helpers ---
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' B='\033[1m' N='\033[0m'
info() { echo -e "${C}[migrate]${N} $*"; }
ok() { echo -e "${G}[migrate]${N} $*"; }
warn() { echo -e "${Y}[migrate]${N} $*"; }
err() { echo -e "${R}[migrate]${N} $*" >&2; }
step() { echo -e "\n${B}=== $* ===${N}"; }

# --- Detect host ---
_omarchy_host() {
	if ssh -o ConnectTimeout=2 -o BatchMode=yes omarchy-local true 2>/dev/null; then
		echo "omarchy-local"
	elif ssh -o ConnectTimeout=3 -o BatchMode=yes omarchy-ts true 2>/dev/null; then
		echo "omarchy-ts"
	else
		return 1
	fi
}

HOST=$(_omarchy_host) || {
	err "omarchy unreachable"
	exit 1
}
info "Using host: $HOST"

# --- Get plan info from DB ---
DB="$HOME/.claude/data/dashboard.db"
PLAN_ROW=$(sqlite3 "$DB" "SELECT name, worktree_path, project_id FROM plans WHERE id = $PLAN_ID;")
if [[ -z "$PLAN_ROW" ]]; then
	err "Plan $PLAN_ID not found in DB"
	exit 1
fi

PLAN_NAME=$(echo "$PLAN_ROW" | cut -d'|' -f1)
MAC_WORKTREE=$(echo "$PLAN_ROW" | cut -d'|' -f2)
PROJECT_ID=$(echo "$PLAN_ROW" | cut -d'|' -f3)

# Resolve worktree path
MAC_WORKTREE_RESOLVED=$(cd "$HOME" && cd "${MAC_WORKTREE/#\~/$HOME}" 2>/dev/null && pwd || echo "$MAC_WORKTREE")
info "Plan: $PLAN_NAME"
info "Mac worktree: $MAC_WORKTREE_RESOLVED"

# Get branch name from worktree
BRANCH=$(git -C "$MAC_WORKTREE_RESOLVED" branch --show-current 2>/dev/null)
if [[ -z "$BRANCH" ]]; then
	err "Could not detect branch in worktree"
	exit 1
fi
info "Branch: $BRANCH"

# Derive Linux paths
WORKTREE_BASENAME=$(basename "$MAC_WORKTREE_RESOLVED")
LINUX_REPO="/home/roberdan/GitHub/Convergio"
LINUX_WORKTREE="/home/roberdan/GitHub/$WORKTREE_BASENAME"

# --- Find main repo (parent of worktree) ---
MAIN_REPO=$(git -C "$MAC_WORKTREE_RESOLVED" rev-parse --git-common-dir 2>/dev/null | sed 's|/.git$||')
info "Main repo: $MAIN_REPO"

START=$(date +%s)

# --- Step 1: Sync dashboard DB ---
step "Step 1/5: Sync dashboard DB"
REMOTE_HOST="$HOST" "$SCRIPT_DIR/sync-dashboard-db.sh" push 2>&1 || warn "DB sync had issues (continuing)"

# --- Step 2: Setup git worktree on Linux ---
step "Step 2/5: Setup git worktree on Linux"
ssh "$HOST" bash -s -- "$LINUX_REPO" "$LINUX_WORKTREE" "$BRANCH" <<'REMOTE_GIT'
set -euo pipefail
REPO="$1"
WT="$2"
BRANCH="$3"

if [[ ! -d "$REPO" ]]; then
  echo "[migrate] ERROR: $REPO not found. Run remote-repo-sync.sh first."
  exit 1
fi

cd "$REPO"
git fetch origin 2>/dev/null

if [[ -d "$WT" ]]; then
  echo "[migrate] Worktree $WT already exists, updating..."
  cd "$WT"
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
  git pull origin "$BRANCH" --ff-only 2>/dev/null || true
else
  echo "[migrate] Creating worktree at $WT..."
  git worktree add "$WT" "$BRANCH" 2>/dev/null || {
    echo "[migrate] Branch not local, fetching..."
    git fetch origin "$BRANCH"
    git worktree add "$WT" "$BRANCH"
  }
fi

echo "[migrate] Worktree ready: $WT"
git -C "$WT" log --oneline -1
REMOTE_GIT

# --- Step 3: Rsync .env and config files ---
step "Step 3/5: Rsync .env and config files"

# .env from main repo root → Linux worktree
if [[ -f "$MAIN_REPO/.env" ]]; then
	scp -q "$MAIN_REPO/.env" "$HOST:$LINUX_WORKTREE/.env"
	ok "Copied .env"
fi
if [[ -f "$MAIN_REPO/.env.example" ]]; then
	scp -q "$MAIN_REPO/.env.example" "$HOST:$LINUX_WORKTREE/.env.example"
	ok "Copied .env.example"
fi

# backend .env
if [[ -f "$MAIN_REPO/backend/.env" ]]; then
	scp -q "$MAIN_REPO/backend/.env" "$HOST:$LINUX_WORKTREE/backend/.env"
	ok "Copied backend/.env"
fi
if [[ -f "$MAIN_REPO/backend/.env.example" ]]; then
	scp -q "$MAIN_REPO/backend/.env.example" "$HOST:$LINUX_WORKTREE/backend/.env.example"
	ok "Copied backend/.env.example"
fi

# .mcp.json if exists
if [[ -f "$MAIN_REPO/.mcp.json" ]]; then
	scp -q "$MAIN_REPO/.mcp.json" "$HOST:$LINUX_WORKTREE/.mcp.json"
	ok "Copied .mcp.json"
fi

# --- Step 4: Install deps on Linux ---
step "Step 4/5: Install dependencies on Linux"
ssh "$HOST" bash -s -- "$LINUX_WORKTREE" <<'REMOTE_DEPS'
set -euo pipefail
WT="$1"

# Frontend
if [[ -f "$WT/frontend/package.json" ]]; then
  echo "[migrate] Installing frontend deps..."
  cd "$WT/frontend"
  npm ci --silent 2>&1 | tail -3
  echo "[migrate] Frontend deps: OK"
fi

# Backend
if [[ -f "$WT/backend/requirements.txt" ]]; then
  echo "[migrate] Setting up backend venv..."
  cd "$WT/backend"
  python3 -m venv venv 2>/dev/null || python3.11 -m venv venv 2>/dev/null || echo "[migrate] WARN: venv creation failed"
  if [[ -f venv/bin/activate ]]; then
    source venv/bin/activate
    pip install -q -r requirements.txt 2>&1 | tail -3
    echo "[migrate] Backend deps: OK"
  fi
fi
REMOTE_DEPS

# --- Step 5: Update DB on Linux ---
step "Step 5/5: Update plan DB on Linux"
LINUX_DB="~/.claude/data/dashboard.db"
ssh "$HOST" bash -s -- "$PLAN_ID" "$LINUX_WORKTREE" <<'REMOTE_DB'
set -euo pipefail
PLAN_ID="$1"
LINUX_WT="$2"
DB="$HOME/.claude/data/dashboard.db"

if [[ ! -f "$DB" ]]; then
  echo "[migrate] ERROR: Dashboard DB not found on Linux"
  exit 1
fi

# Update worktree path and execution host
sqlite3 "$DB" "UPDATE plans SET worktree_path = '$LINUX_WT', execution_host = 'omarchy' WHERE id = $PLAN_ID;"

# Verify
echo "[migrate] DB updated:"
sqlite3 "$DB" "SELECT id, name, status, execution_host, worktree_path FROM plans WHERE id = $PLAN_ID;"
REMOTE_DB

# --- Summary ---
END=$(date +%s)
ELAPSED=$((END - START))
echo ""
step "Migration complete (${ELAPSED}s)"
echo -e "  Plan:     ${C}#${PLAN_ID}${N} $PLAN_NAME"
echo -e "  Branch:   ${C}${BRANCH}${N}"
echo -e "  Linux WT: ${C}${LINUX_WORKTREE}${N}"
echo -e "  Host:     ${C}${HOST}${N}"
echo ""
echo -e "  ${B}Next:${N} Connect via tmux and run Claude:"
echo -e "    ${G}tlx${N}"
echo -e "    ${G}cd $LINUX_WORKTREE && claude --resume${N}"
echo -e "    or: ${G}/execute 193${N}"
