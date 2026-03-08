#!/usr/bin/env bash
# hook-checks.sh — shared check functions for hooks/dispatcher.sh
set -uo pipefail

DISPATCH_DECISION_JSON="${DISPATCH_DECISION_JSON:-}"
DISPATCH_ENV_GH_TOKEN="${DISPATCH_ENV_GH_TOKEN:-}"

deny_permission() {
	local reason="$1"
	DISPATCH_DECISION_JSON="$(jq -cn --arg r "$reason" '{permissionDecision:"deny",permissionDecisionReason:$r}')"
}

check_gh_auto_token() {
	local config_file="$HOME/.claude/config/gh-accounts.json"
	[[ -n "${COMMAND:-}" ]] || return 0
	[[ -f "$config_file" ]] || return 0
	case "$COMMAND" in
	*gh\ *|*pr-ops*|*wave-worktree*|*ci-digest*|*ci-watch*|*pr-threads*|*pr-digest*|*service-digest*|*git\ push*|*git\ fetch*|*git\ pull*) ;;
	*) return 0 ;;
	esac
	local account token
	account="$(jq -r --arg cwd "$PWD" --arg home "$HOME" '
		(.default_account // "") as $default |
		[.mappings[]? | select(
			($cwd == (.path | gsub("~"; $home) | rtrimstr("/"))) or
			($cwd | startswith((.path | gsub("~"; $home) | rtrimstr("/")) + "/"))
		) | {path: (.path | gsub("~"; $home) | length), account}] |
		sort_by(-.path) | .[0].account // $default
	' "$config_file" 2>/dev/null || true)"
	[[ -n "$account" ]] || return 0
	token="$(gh auth token --user "$account" 2>/dev/null || true)"
	[[ -n "$token" ]] || return 0
	DISPATCH_ENV_GH_TOKEN="$token"
	return 0
}

check_worktree_guard() {
	[[ -n "${COMMAND:-}" ]] || return 0
	if [[ "$COMMAND" =~ git[[:space:]]+worktree[[:space:]]+add ]]; then
		local git_root wt_path resolved real_root
		git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
		wt_path="$(echo "$COMMAND" | sed -E 's/.*git worktree add (-b [^ ]+ )?//' | awk '{print $1}')"
		if [[ -n "$wt_path" && -n "$git_root" ]]; then
			resolved="$(cd "$(dirname "$wt_path")" 2>/dev/null && echo "$(pwd -P)/$(basename "$wt_path")" || true)"
			real_root="$(cd "$git_root" 2>/dev/null && pwd -P || echo "$git_root")"
			if [[ -n "$resolved" && "$resolved" == "$real_root"/* ]]; then
				deny_permission "WORKTREE GUARD: Path is INSIDE the repo. Use a SIBLING path instead."
				return 1
			fi
		fi
		return 0
	fi
	[[ "$COMMAND" =~ git[[:space:]]+worktree[[:space:]]+remove ]] && { deny_permission "Use worktree-cleanup.sh instead of direct git worktree remove."; return 1; }
	if echo "$COMMAND" | grep -qE 'git (branch [^-]|checkout -b|switch -c)' && ! echo "$COMMAND" | grep -qE 'git branch (-d|-D|--list|--show|--merged|--no-merged|--contains)'; then
		deny_permission "BLOCKED: Never create bare branches. Use worktree-create.sh or wave-worktree.sh create instead. See worktree-discipline.md § No Bare Branches."
		return 1
	fi
	echo "$COMMAND" | grep -qE '^git (commit|push|add|checkout|merge|rebase|reset|stash)' || return 0
	local current_branch
	current_branch="$(git branch --show-current 2>/dev/null || echo DETACHED)"
	if [[ "$current_branch" == "main" || "$current_branch" == "master" ]] && [[ "${CLAUDE_MAIN_WRITE_ALLOWED:-0}" != "1" ]]; then
		deny_permission "BLOCKED: Git write on ${current_branch} is forbidden. Work in a worktree. Set CLAUDE_MAIN_WRITE_ALLOWED=1 only with explicit user permission."
		return 1
	fi
}

check_warn_bash_antipatterns() {
	[[ -n "${COMMAND:-}" ]] || return 0
	if echo "$COMMAND" | grep -qE 'sqlite3.*"[^"]*!=.*"'; then
		echo "BLOCKED: '!=' inside double-quoted sqlite3 command will break in zsh (! expansion)." >&2
		echo "Fix: Use SQL '<>' operator or 'NOT IN (...)' instead of '!='." >&2
		return 2
	fi
	if echo "$COMMAND" | grep -qE '(^| )find '; then echo "ANTIPATTERN: Use Glob tool instead of bash" >&2; fi
	if echo "$COMMAND" | grep -qE '(^grep |^rg | \| *grep )'; then echo "ANTIPATTERN: Use Grep tool instead of bash" >&2; fi
	if echo "$COMMAND" | grep -qE '(^cat [^|<>]+$|^head |^tail )'; then echo "ANTIPATTERN: Use Read tool instead of bash" >&2; fi
	if echo "$COMMAND" | grep -qE '(^sed .* -i|^awk )'; then echo "ANTIPATTERN: Use Edit tool instead of bash" >&2; fi
	if echo "$COMMAND" | grep -qE '(^echo .+>|^printf .+>|cat <<)'; then echo "ANTIPATTERN: Use Write tool instead of bash" >&2; fi
}

check_prefer_ci_summary() {
	[[ -n "${COMMAND:-}" ]] || return 0
	local base_cmd
	base_cmd="$(echo "$COMMAND" | sed 's/|.*//' | sed 's/.*&&//' | sed 's/.*;//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
	echo "$COMMAND" | grep -qE "digest\.sh|service-digest|pr-ops\.sh|code-pattern-check\.sh|ci-summary\.sh --(quick|full|all|lint|types|build|unit|i18n|e2e|a11y)|(\./scripts/|npm run )(release|pre-push|pre-release)" && return 0
	if echo "$COMMAND" | grep -qE "wc -l" && ! echo "$base_cmd" | grep -qE "^git (commit|tag)"; then echo "Hint: grep -c . <file>" >&2; fi
	echo "$base_cmd" | grep -qE "gh run view.*--log" && { echo "Use: service-digest.sh ci <run-id>" >&2; return 2; }
	echo "$base_cmd" | grep -qE "gh pr view.*--comments" && { echo "Use: service-digest.sh pr <pr>" >&2; return 2; }
	if echo "$base_cmd" | grep -qE "gh api.*pulls/[0-9]+/(comments|reviews)"; then
		echo "$COMMAND" | grep -qE " -[fF] | --method | -X " || { echo "Use: service-digest.sh pr <pr>" >&2; return 2; }
		echo "$COMMAND" | grep -qE " -[fF] | -X " && echo "Hint: pr-ops.sh reply <pr> <id> \"msg\"" >&2
	fi
	echo "$base_cmd" | grep -qE "^gh pr merge" && { echo "Use: pr-ops.sh merge <pr>" >&2; return 2; }
	if echo "$base_cmd" | grep -qE "^gh pr view" && ! echo "$COMMAND" | grep -qE "\-\-json"; then echo "Use: pr-ops.sh status <pr>" >&2; return 2; fi
	echo "$base_cmd" | grep -qE "^gh pr checks" && { echo "Use: ci-digest.sh checks <pr>" >&2; return 2; }
	echo "$base_cmd" | grep -qE "^gh " && return 0
	echo "$base_cmd" | grep -qE "(^vercel logs|vercel-helper\.sh logs)" && { echo "Use: service-digest.sh deploy" >&2; return 2; }
	echo "$base_cmd" | grep -qE "^npm (install|ci)( |$)" && { echo "Use: npm-digest.sh install" >&2; return 2; }
	if echo "$base_cmd" | grep -qE "^npm audit( |$)" && ! echo "$COMMAND" | grep -q "\-\-json"; then echo "Use: audit-digest.sh" >&2; return 2; fi
	echo "$base_cmd" | grep -qE "^npm run build( |$)" && { echo "Use: build-digest.sh" >&2; return 2; }
	if echo "$base_cmd" | grep -qE "^(npx (vitest|jest|playwright)|npm run test|npm test)( |$)"; then [ -f "./scripts/ci-summary.sh" ] && echo "Use: ./scripts/ci-summary.sh --unit|--e2e" >&2 || echo "Use: test-digest.sh" >&2; return 2; fi
	if echo "$base_cmd" | grep -qE "^npm run (lint|typecheck|test:unit)( |$)"; then [ -f "./scripts/ci-summary.sh" ] && echo "Use: ./scripts/ci-summary.sh --quick" >&2 || echo "Use: test-digest.sh" >&2; return 2; fi
	if echo "$base_cmd" | grep -qE "^(npm run ci:summary|\\./scripts/ci-summary\\.sh)( |$)" && [ -f "./scripts/ci-summary.sh" ]; then echo "Hint: ci-summary.sh --quick (faster)" >&2; fi
	if echo "$base_cmd" | grep -qE "^git diff"; then echo "$base_cmd" | grep -qE "^git diff --stat( |$)" || { echo "Use: git-digest.sh --full or diff-digest.sh" >&2; return 2; }; fi
	echo "$COMMAND" | grep -qE "prisma migrate (dev.*--create-only|diff)" && return 0
	if echo "$base_cmd" | grep -qE "^npx (prisma|drizzle-kit) (migrate|db push|generate|check)"; then echo "Use: migration-digest.sh" >&2; return 2; fi
	echo "$base_cmd" | grep -qE "^git status( |$)" && { echo "Use: git-digest.sh" >&2; return 2; }
	if echo "$base_cmd" | grep -qE "^git log( |$)" && ! echo "$COMMAND" | grep -qE "\-\-(oneline|format)"; then echo "Use: git-digest.sh" >&2; return 2; fi
	if echo "$base_cmd" | grep -qE "^git show( |$)" && ! echo "$COMMAND" | grep -qE "\-\-(oneline|format|stat)"; then echo "Use: git log --oneline --stat <sha> -1" >&2; return 2; fi
}

check_warn_infra_plan_drift() {
	local db="$HOME/.claude/data/dashboard.db"
	[[ -f "$db" ]] || return 0
	echo "$COMMAND" | grep -qE 'az (containerapp|acr |postgres|redis |keyvault|storage |deployment group|webapp create|webapp update)' || return 0
	local db_rows pending tasks
	db_rows="$(sqlite3 "$db" "
SELECT COUNT(*) FROM tasks t JOIN plans p ON t.plan_id = p.id WHERE p.status='doing' AND t.status IN ('pending','in_progress') AND (t.title LIKE '%Azure%' OR t.title LIKE '%Bicep%' OR t.title LIKE '%ACR%' OR t.title LIKE '%Container%' OR t.title LIKE '%Redis%' OR t.title LIKE '%PostgreSQL%' OR t.title LIKE '%Key Vault%' OR t.title LIKE '%Storage%' OR t.title LIKE '%MI %' OR t.title LIKE '%Managed Identity%' OR t.title LIKE '%deploy%' OR t.title LIKE '%provision%');
SELECT COALESCE(group_concat(x, char(10)), '') FROM (SELECT t.task_id || ': ' || t.title AS x FROM tasks t JOIN plans p ON t.plan_id=p.id WHERE p.status='doing' AND t.status IN ('pending','in_progress') AND (t.title LIKE '%Azure%' OR t.title LIKE '%Bicep%' OR t.title LIKE '%ACR%' OR t.title LIKE '%Container%' OR t.title LIKE '%Redis%' OR t.title LIKE '%PostgreSQL%' OR t.title LIKE '%Key Vault%' OR t.title LIKE '%Storage%' OR t.title LIKE '%MI %' OR t.title LIKE '%Managed Identity%' OR t.title LIKE '%deploy%' OR t.title LIKE '%provision%') LIMIT 5);
" 2>/dev/null || true)"
	pending="$(printf '%s\n' "$db_rows" | sed -n '1p')"
	tasks="$(printf '%s\n' "$db_rows" | sed -n '2p')"
	[[ "${pending:-0}" =~ ^[0-9]+$ ]] || pending=0
	if ((pending > 0)); then
		cat >&2 <<EOF
[ADR-054] INFRA PLAN DRIFT WARNING
Running az infra command while ${pending} infra task(s) are pending in active plan.
Matching tasks:
${tasks}
ACTION REQUIRED: Update plan-db BEFORE or AFTER this operation.
  plan-db.sh update-task <id> in_progress  (before)
  plan-db-safe.sh update-task <id> done "evidence" (after)
EOF
	fi
}

check_enforce_execution_preflight() {
	echo "$COMMAND" | grep -qE 'execute-plan\.sh|copilot-worker\.sh|plan-db\.sh[[:space:]]+start|plan-db\.sh[[:space:]]+validate-(task|wave)|wave-worktree\.sh[[:space:]]+(merge|batch)' || return 0
	echo "$COMMAND" | grep -q 'execution-preflight\.sh' && return 0
	local plan_id snapshot now generated age
	plan_id="$(echo "$COMMAND" | sed -nE 's/.*plan-db\.sh[[:space:]]+start[[:space:]]+([0-9]+).*/\1/p')"
	[[ -n "$plan_id" ]] || plan_id="$(echo "$COMMAND" | sed -nE 's/.*(execute-plan|copilot-worker)\.sh[[:space:]]+([0-9]+).*/\2/p')"
	[[ -n "$plan_id" ]] || [[ ! -f "$HOME/.claude/data/active-plan-id.txt" ]] || plan_id="$(grep -m1 -E '^[0-9]+$' "$HOME/.claude/data/active-plan-id.txt" 2>/dev/null || true)"
	[[ -n "$plan_id" ]] || return 0
	snapshot="$HOME/.claude/data/execution-preflight/plan-${plan_id}.json"
	[[ -f "$snapshot" ]] || { deny_permission "BLOCKED: missing execution preflight snapshot for plan ${plan_id}. Run execution-preflight.sh --plan-id ${plan_id} <worktree> before risky plan commands."; return 1; }
	now="$(date +%s)"; generated="$(jq -r '.generated_epoch // 0' "$snapshot" 2>/dev/null || echo 0)"; age=$((now - generated))
	((age <= 1800)) || { deny_permission "BLOCKED: execution preflight for plan ${plan_id} is stale (${age}s). Refresh preflight before continuing."; return 1; }
	jq -e '.warnings | index("dirty_worktree")' "$snapshot" >/dev/null 2>&1 && { deny_permission "BLOCKED: plan ${plan_id} has dirty_worktree in the latest execution preflight snapshot."; return 1; }
	jq -e '.warnings | index("gh_auth_not_ready")' "$snapshot" >/dev/null 2>&1 && { deny_permission "BLOCKED: plan ${plan_id} has gh_auth_not_ready in the latest execution preflight snapshot."; return 1; }
}

check_plan_db_validation_hints() {
	# Ownership is centralized in plan-db script guards:
	# - scripts/plan-db.sh update-task guard for done/submitted transitions
	# - cmd_start + cmd_check_readiness for planner review gates
	# - cmd_complete for Thor completion gates
	if echo "$COMMAND" | grep -qE "plan-db\.sh[[:space:]]+update-task[[:space:]].*[[:space:]](done|submitted)"; then
		echo "Hint: plan-db.sh enforces done/submitted transitions. Use plan-db-safe.sh update-task <id> done ..." >&2
		return 0
	fi
	if echo "$COMMAND" | grep -qE 'plan-db\.sh[[:space:]]+start([[:space:]]|$)'; then
		echo "Hint: plan-db.sh start already enforces planner gates via cmd_check_readiness." >&2
		return 0
	fi
	if echo "$COMMAND" | grep -qE 'plan-db\.sh[[:space:]]+complete([[:space:]]|$)'; then
		echo "Hint: plan-db.sh complete already enforces Thor completion gates." >&2
		return 0
	fi
	return 0
}

check_env_vault_guard() {
local command
command=$(echo "$HOOK_INPUT" | jq -r '.toolArgs.command // .tool_input.command // ""' 2>/dev/null)
if ! echo "$command" | grep -qE '(^|[;&[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
return 0
fi
local patterns='API_KEY=|SECRET=|PASSWORD=|CONNECTION_STRING=|private_key|token'
local files
files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
for f in $files; do
[ -f "$f" ] || continue
if grep -E "$patterns" "$f" >/dev/null 2>&1; then
jq -n --arg r "BLOCKED: Secret-like pattern found in staged file: $f" \
'{permissionDecision: "deny", permissionDecisionReason: $r}'
return 0
fi
done
return 0
}
