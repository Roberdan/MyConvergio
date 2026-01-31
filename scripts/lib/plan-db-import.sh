#!/bin/bash
# Plan DB Import, Render & Context - Bulk operations + execution context
# Sourced by plan-db.sh

# Import waves and tasks from a spec.json file
# Usage: import <plan_id> <spec_file>
cmd_import() {
	local plan_id="$1"
	local spec_file="$2"

	[[ ! -f "$spec_file" ]] && {
		log_error "Spec file not found: $spec_file"
		exit 1
	}

	# Save spec alongside plan markdown
	local markdown_path
	markdown_path=$(sqlite3 "$DB_FILE" "SELECT markdown_path FROM plans WHERE id=$plan_id;")
	if [[ -n "$markdown_path" ]]; then
		local plan_dir
		plan_dir=$(dirname "$(_expand_path "$markdown_path")")
		mkdir -p "$plan_dir"
		cp "$spec_file" "$plan_dir/spec.json"
	fi

	local wave_count
	wave_count=$(jq '.waves | length' "$spec_file")
	local total_tasks=0

	for ((i = 0; i < wave_count; i++)); do
		local w_id w_name w_hours w_depends
		w_id=$(jq -r ".waves[$i].id" "$spec_file")
		w_name=$(jq -r ".waves[$i].name" "$spec_file")
		w_hours=$(jq -r ".waves[$i].estimated_hours // 8" "$spec_file")
		w_depends=$(jq -r ".waves[$i].depends_on // empty" "$spec_file")

		local wave_args=("$plan_id" "$w_id" "$w_name" --estimated-hours "$w_hours")
		[[ -n "$w_depends" ]] && wave_args+=(--depends-on "$w_depends")

		local db_wave_id
		db_wave_id=$(cmd_add_wave "${wave_args[@]}" 2>/dev/null)

		local task_count
		task_count=$(jq ".waves[$i].tasks | length" "$spec_file")

		for ((j = 0; j < task_count; j++)); do
			local t_id t_title t_pri t_type t_model t_desc t_criteria
			t_id=$(jq -r ".waves[$i].tasks[$j].id" "$spec_file")
			t_title=$(jq -r ".waves[$i].tasks[$j].title" "$spec_file")
			t_pri=$(jq -r ".waves[$i].tasks[$j].priority // \"P1\"" "$spec_file")
			t_type=$(jq -r ".waves[$i].tasks[$j].type // \"feature\"" "$spec_file")
			t_model=$(jq -r ".waves[$i].tasks[$j].model // \"sonnet\"" "$spec_file")
			t_desc=$(jq -r ".waves[$i].tasks[$j].description // \"\"" "$spec_file")
			t_criteria=$(jq -c ".waves[$i].tasks[$j].test_criteria // []" "$spec_file")

			local task_args=("$db_wave_id" "$t_id" "$t_title" "$t_pri" "$t_type")
			task_args+=(--model "$t_model")
			[[ -n "$t_desc" ]] && task_args+=(--description "$t_desc")
			if [[ "$t_criteria" != "[]" && "$t_criteria" != "null" ]]; then
				# Wrap in {"verify":[...]} format expected by Thor
				t_criteria=$(echo "$t_criteria" | jq -c '{verify: .}')
				task_args+=(--test-criteria "$t_criteria")
			fi

			cmd_add_task "${task_args[@]}" 2>/dev/null
			total_tasks=$((total_tasks + 1))
		done
	done

	log_info "Imported $wave_count waves, $total_tasks tasks"

	# Auto-render markdown
	cmd_render "$plan_id" >/dev/null
}

# Render plan markdown from DB + spec.json
# Usage: render <plan_id>
# Output: writes to markdown_path and prints to stdout
cmd_render() {
	local plan_id="$1"

	local plan_info
	plan_info=$(sqlite3 -separator '|' "$DB_FILE" "
        SELECT name, project_id, status,
               COALESCE(worktree_path,''), COALESCE(source_file,''),
               COALESCE(markdown_path,'')
        FROM plans WHERE id=$plan_id;")

	local plan_name project_id plan_status wt_path source_file md_path
	IFS='|' read -r plan_name project_id plan_status \
		wt_path source_file md_path <<<"$plan_info"

	wt_path=$(_expand_path "$wt_path")
	local branch=""
	if [[ -d "$wt_path/.git" ]] || [[ -f "$wt_path/.git" ]]; then
		branch=$(cd "$wt_path" && git branch --show-current 2>/dev/null || echo "")
	fi

	# Locate spec.json for requirements + user_request
	local spec_file=""
	if [[ -n "$md_path" ]]; then
		local candidate
		candidate="$(dirname "$(_expand_path "$md_path")")/spec.json"
		[[ -f "$candidate" ]] && spec_file="$candidate"
	fi

	# Determine output file
	local output_file=""
	if [[ -n "$md_path" ]]; then
		output_file=$(_expand_path "$md_path")
		mkdir -p "$(dirname "$output_file")"
	fi

	# Generate markdown
	{
		echo "# Piano: $plan_name"
		echo "**Project**: $project_id | **Plan ID**: $plan_id | **Status**: $plan_status"
		[[ -n "$wt_path" && "$wt_path" != "." ]] && echo "**Worktree**: \`$wt_path\`"
		[[ -n "$branch" ]] && echo "**Branch**: \`$branch\`"
		echo ""

		echo "## USER REQUEST"
		if [[ -n "$spec_file" ]]; then
			jq -r '.user_request // "" | split("\n")[] | "> " + .' "$spec_file" 2>/dev/null || echo "> [see source file]"
		elif [[ -n "$source_file" ]]; then
			echo "> [See source: $source_file]"
		fi
		echo ""

		echo "## FUNCTIONAL REQUIREMENTS"
		echo "| ID | Requirement | Wave | Verified |"
		echo "|----|-------------|------|----------|"
		if [[ -n "$spec_file" ]]; then
			jq -r '.requirements // [] | .[] | "| \(.id) | \(.text) | \(.wave) | [ ] |"' \
				"$spec_file" 2>/dev/null || true
		fi
		echo ""

		echo "## WAVES"
		sqlite3 -separator '|' "$DB_FILE" "
            SELECT id, wave_id, name, status, tasks_done, tasks_total
            FROM waves WHERE plan_id=$plan_id ORDER BY position;
        " | while IFS='|' read -r wid wid_text wname wstatus wdone wtotal; do
			echo ""
			echo "### $wid_text: $wname"
			echo "Status: $wstatus ($wdone/$wtotal)"
			echo ""
			echo "| Task | Description | Priority | Model | Status |"
			echo "|------|-------------|----------|-------|--------|"
			sqlite3 -separator '|' "$DB_FILE" "
                SELECT task_id, title, priority, model, status
                FROM tasks WHERE wave_id_fk=$wid ORDER BY task_id;
            " | while IFS='|' read -r tid title pri model tstatus; do
				echo "| $tid | $title | $pri | $model | $tstatus |"
			done
		done
		echo ""

		echo "## LEARNINGS LOG"
		echo "| Wave | Issue | Root Cause | Resolution | Preventive Rule |"
		echo "|------|-------|------------|------------|-----------------|"
	} | if [[ -n "$output_file" ]]; then
		tee "$output_file"
		log_info "Rendered: $output_file" >&2
	else
		cat
	fi
}

# Get full execution context for a plan in single JSON
# Replaces 5+ separate DB queries in execute.md
# Usage: get-context <plan_id>
cmd_get_context() {
	local plan_id="$1"

	local plan_json
	plan_json=$(sqlite3 "$DB_FILE" "
		SELECT json_object(
			'id', id, 'name', name, 'status', status,
			'tasks_done', tasks_done, 'tasks_total', tasks_total,
			'markdown_path', COALESCE(markdown_path,''),
			'source_file', COALESCE(source_file,''),
			'worktree_path', COALESCE(worktree_path,'')
		) FROM plans WHERE id=$plan_id;")

	if [[ -z "$plan_json" ]]; then
		log_error "Plan $plan_id not found"
		exit 1
	fi

	# Expand paths (replace ~ with $HOME)
	local wt_expanded md_expanded
	wt_expanded=$(_expand_path "$(echo "$plan_json" | jq -r '.worktree_path')")
	md_expanded=$(_expand_path "$(echo "$plan_json" | jq -r '.markdown_path')")

	# Pending + in_progress tasks with wave info (ordered)
	local tasks_json
	tasks_json=$(sqlite3 "$DB_FILE" "
		SELECT COALESCE(json_group_array(json_object(
			'db_id', t.id, 'task_id', t.task_id, 'title', t.title,
			'description', COALESCE(t.description,''),
			'status', t.status, 'priority', t.priority,
			'test_criteria', COALESCE(t.test_criteria,''),
			'model', COALESCE(t.model, 'sonnet'),
			'wave_db_id', w.id, 'wave_id', w.wave_id,
			'wave_name', w.name,
			'wave_tasks_done', w.tasks_done,
			'wave_tasks_total', w.tasks_total
		)), '[]')
		FROM tasks t
		JOIN waves w ON t.wave_id_fk = w.id
		WHERE t.plan_id = $plan_id AND t.status IN ('pending', 'in_progress')
		ORDER BY w.position, t.task_id;")

	# Detect test framework from worktree
	local framework="unknown"
	if [[ -d "$wt_expanded" && -f "$wt_expanded/package.json" ]]; then
		if grep -q '"vitest"' "$wt_expanded/package.json" 2>/dev/null; then
			framework="vitest"
		elif grep -q '"jest"' "$wt_expanded/package.json" 2>/dev/null; then
			framework="jest"
		elif grep -q '"playwright"' "$wt_expanded/package.json" 2>/dev/null; then
			framework="playwright"
		else
			framework="node"
		fi
	elif [[ -f "$wt_expanded/pyproject.toml" ]]; then
		framework="pytest"
	elif [[ -f "$wt_expanded/Cargo.toml" ]]; then
		framework="cargo"
	fi

	# Combine into single JSON
	echo "$plan_json" | jq \
		--arg wt "$wt_expanded" \
		--arg md "$md_expanded" \
		--argjson tasks "$tasks_json" \
		--arg fw "$framework" \
		'. + {
			worktree_path: $wt,
			markdown_path: $md,
			pending_tasks: $tasks,
			framework: $fw
		}'
}
