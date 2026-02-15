#!/bin/bash
# thor-git-hook.sh - Native git pre-commit hook for Thor validation
# Version: 1.0.0
# Blocks commits when active plan has unvalidated done tasks.
# Works as: .git/hooks/pre-commit OR .husky/pre-commit entry
# Install: thor-git-hook.sh install [repo_path]
set -euo pipefail

DB_FILE="${HOME}/.claude/data/dashboard.db"

cmd_check() {
	# Skip if no database
	[[ ! -f "$DB_FILE" ]] && return 0

	# Derive project_id from cwd
	local project_id
	project_id=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

	# Check for unvalidated done tasks in active plans
	local unvalidated
	unvalidated=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" "
		SELECT t.task_id, t.title FROM tasks t
		JOIN waves w ON t.wave_id_fk = w.id
		JOIN plans p ON w.plan_id = p.id
		WHERE p.project_id = '$project_id'
		  AND p.status IN ('todo', 'doing')
		  AND t.status = 'done'
		  AND t.validated_at IS NULL
		LIMIT 10;
	" 2>/dev/null) || true

	if [[ -n "$unvalidated" ]]; then
		echo "BLOCKED: Unvalidated tasks found. Run per-task Thor validation first:" >&2
		echo "$unvalidated" | while IFS='|' read -r tid title; do
			echo "  - $tid: $title" >&2
		done
		echo "" >&2
		echo "Fix: plan-db.sh validate-task <task_id> <plan_id>" >&2
		return 1
	fi

	return 0
}

cmd_install() {
	local repo_path="${1:-.}"
	repo_path=$(cd "$repo_path" && pwd)

	if [[ ! -d "$repo_path/.git" ]]; then
		echo "ERROR: $repo_path is not a git repository" >&2
		return 1
	fi

	local hook_dir="$repo_path/.git/hooks"
	local hook_file="$hook_dir/pre-commit"
	local self_path
	self_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

	# If pre-commit exists, append; otherwise create
	if [[ -f "$hook_file" ]]; then
		# Check if already installed
		if grep -q "thor-git-hook" "$hook_file" 2>/dev/null; then
			echo "Already installed in $hook_file"
			return 0
		fi
		echo "" >>"$hook_file"
		echo "# Thor validation guard (blocks commits with unvalidated tasks)" >>"$hook_file"
		echo "\"$self_path\" check || exit 1" >>"$hook_file"
		echo "Appended to existing $hook_file"
	else
		cat >"$hook_file" <<HOOK
#!/bin/bash
# Thor validation guard (blocks commits with unvalidated tasks)
"$self_path" check || exit 1
HOOK
		chmod +x "$hook_file"
		echo "Created $hook_file"
	fi
}

cmd_uninstall() {
	local repo_path="${1:-.}"
	repo_path=$(cd "$repo_path" && pwd)
	local hook_file="$repo_path/.git/hooks/pre-commit"

	if [[ -f "$hook_file" ]] && grep -q "thor-git-hook" "$hook_file" 2>/dev/null; then
		# Remove our lines
		grep -v "thor-git-hook\|Thor validation guard" "$hook_file" >"$hook_file.tmp" || true
		mv "$hook_file.tmp" "$hook_file"
		chmod +x "$hook_file"
		echo "Removed from $hook_file"
	else
		echo "Not installed in $hook_file"
	fi
}

case "${1:-check}" in
check) cmd_check ;;
install) cmd_install "${2:-.}" ;;
uninstall) cmd_uninstall "${2:-.}" ;;
*)
	echo "Usage: thor-git-hook.sh <check|install [repo]|uninstall [repo]>"
	;;
esac
