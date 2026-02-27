#!/bin/bash
# Plan DB Import, Render & Context - Bulk operations + execution context
# Sourced by plan-db.sh

# Import waves and tasks from a spec file (JSON or YAML)
# Usage: import <plan_id> <spec_file>
# Version: 1.3.0
cmd_import() {
	local plan_id="$1"
	local spec_file="$2"

	[[ ! -f "$spec_file" ]] && {
		log_error "Spec file not found: $spec_file"
		exit 1
	}

	# YAML support: convert to temp JSON if file is YAML
	local effective_spec
	effective_spec=$(yaml_to_json_temp "$spec_file") || exit 1
	[[ "$effective_spec" != "$spec_file" ]] && log_info "Converted YAML spec to JSON: $spec_file"

	# Save spec in plan folder
	local project_id
	project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id=$plan_id;")
	local plan_name
	plan_name=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id=$plan_id;")
	local plan_dir="${HOME}/.claude/plans/${project_id}"
	mkdir -p "$plan_dir"
	# Preserve original extension (.yaml or .json) for the saved copy
	local spec_ext="${spec_file##*.}"
	local saved_spec="$plan_dir/${plan_name}-spec.${spec_ext}"
	if [[ "$spec_file" != "$saved_spec" ]]; then
		cp "$spec_file" "$saved_spec"
	fi

	# Store constraints from spec (ADR-054: constraints are first-class citizens)
	local constraints_json
	constraints_json=$(jq -c '.constraints // []' "$effective_spec" 2>/dev/null)
	if [[ "$constraints_json" != "[]" ]]; then
		sqlite3 "$DB_FILE" "UPDATE plans SET constraints_json = '$(sql_escape "$constraints_json")' WHERE id=$plan_id;"
		local constraint_count
		constraint_count=$(echo "$constraints_json" | jq 'length')
		log_info "Stored $constraint_count constraints for plan #$plan_id"
	fi

	# Auto-set plan description from spec if not already set
	local existing_desc
	existing_desc=$(sqlite3 "$DB_FILE" "SELECT description FROM plans WHERE id=$plan_id;")
	if [[ -z "$existing_desc" || "$existing_desc" == "{" ]]; then
		local spec_desc
		spec_desc=$(jq -r '.description // .user_request // empty' "$effective_spec" 2>/dev/null | head -1 | cut -c1-200)
		if [[ -n "$spec_desc" ]]; then
			sqlite3 "$DB_FILE" "UPDATE plans SET description = '$(sql_escape "$spec_desc")' WHERE id=$plan_id;"
			log_info "Set plan description from spec"
		fi
	fi

	# Read entire spec with a single jq call to avoid hundreds of subprocesses
	local spec_data
	spec_data=$(jq -c '{
		waves: [.waves[] | {
			id: .id,
			name: .name,
			hours: (.estimated_hours // 8),
			depends: (.depends_on // ""),
			precondition: (.precondition // null),
			tasks: [.tasks[] | {
				id: .id,
				title: (if has("do") then .do else .title end),
				priority: (.priority // "P1"),
				type: (.type // "feature"),
				model: (.model // "sonnet"),
				effort: (.effort // 1),
				executor_agent: (.executor_agent // (
  if (.model // "") | test("^gpt-") then "copilot"
  elif (.model // "") | test("^gemini") then "gemini"
  elif (.model // "") == "manual" then "manual"
  elif (.codex // false) then "codex"
  else "claude" end
)),
				has_do: has("do"),
				summary: (.summary // ""),
				files: (.files // [] | join(", ")),
				ref: (.ref // ""),
				verify: (.verify // []),
				description: (.description // ""),
				test_criteria: (.test_criteria // [])
			}]
		}]
	}' "$effective_spec")

	local wave_count total_tasks=0
	wave_count=$(echo "$spec_data" | jq '.waves | length')

	for ((i = 0; i < wave_count; i++)); do
		local w_id w_name w_hours w_depends w_precondition
		w_id=$(echo "$spec_data" | jq -r ".waves[$i].id")
		w_name=$(echo "$spec_data" | jq -r ".waves[$i].name")
		w_hours=$(echo "$spec_data" | jq -r ".waves[$i].hours")
		w_depends=$(echo "$spec_data" | jq -r ".waves[$i].depends")
		w_precondition=$(echo "$spec_data" | jq -c ".waves[$i].precondition // empty")

		local wave_args=("$plan_id" "$w_id" "$w_name" --estimated-hours "$w_hours")
		[[ -n "$w_depends" ]] && wave_args+=(--depends-on "$w_depends")
		[[ -n "$w_precondition" ]] && wave_args+=(--precondition "$w_precondition")

		local db_wave_id
		db_wave_id=$(cmd_add_wave "${wave_args[@]}") || {
			log_error "Failed to add wave $w_id"
			return 1
		}

		local task_count
		task_count=$(echo "$spec_data" | jq ".waves[$i].tasks | length")

		for ((j = 0; j < task_count; j++)); do
			local t_id t_title t_pri t_type t_model t_effort t_desc t_criteria t_executor_agent
			local t_base=".waves[$i].tasks[$j]"
			t_id=$(echo "$spec_data" | jq -r "$t_base.id")
			t_title=$(echo "$spec_data" | jq -r "$t_base.title")
			t_pri=$(echo "$spec_data" | jq -r "$t_base.priority")
			t_type=$(echo "$spec_data" | jq -r "$t_base.type")
			t_model=$(echo "$spec_data" | jq -r "$t_base.model")
			t_effort=$(echo "$spec_data" | jq -r "$t_base.effort")
			t_executor_agent=$(echo "$spec_data" | jq -r "$t_base.executor_agent")

			local has_do t_summary
			has_do=$(echo "$spec_data" | jq -r "$t_base.has_do")
			t_summary=$(echo "$spec_data" | jq -r "$t_base.summary")
			if [[ "$has_do" == "true" ]]; then
				local t_files t_ref
				t_files=$(echo "$spec_data" | jq -r "$t_base.files")
				t_ref=$(echo "$spec_data" | jq -r "$t_base.ref")
				t_desc="$t_title"
				[[ -n "$t_files" ]] && t_desc="$t_desc | Files: $t_files"
				[[ -n "$t_ref" ]] && t_desc="$t_desc | Ref: $t_ref"
				# If summary provided, use it as title and full 'do' as description
				if [[ -n "$t_summary" ]]; then
					t_title="$t_summary"
				fi
				t_criteria=$(echo "$spec_data" | jq -c "$t_base.verify")
			else
				t_desc=$(echo "$spec_data" | jq -r "$t_base.description")
				t_criteria=$(echo "$spec_data" | jq -c "$t_base.test_criteria")
			fi

			local task_args=("$db_wave_id" "$t_id" "$t_title" "$t_pri" "$t_type")
			task_args+=(--model "$t_model" --effort "$t_effort")
			[[ -n "$t_desc" ]] && task_args+=(--description "$t_desc")
			if [[ "$t_criteria" != "[]" && "$t_criteria" != "null" ]]; then
				t_criteria=$(echo "$t_criteria" | jq -c '{verify: .}')
				task_args+=(--test-criteria "$t_criteria")
			fi
			[[ -n "$t_executor_agent" ]] && task_args+=(--executor-agent "$t_executor_agent")

			if ! cmd_add_task "${task_args[@]}"; then
				log_error "Failed to add task $t_id to wave $w_id"
				return 1
			fi
			total_tasks=$((total_tasks + 1))
		done
	done

	# Link source_file in plans table if not set
	local current_source
	current_source=$(sqlite3 "$DB_FILE" "SELECT source_file FROM plans WHERE id=$plan_id;")
	if [[ -z "$current_source" || "$current_source" == "" ]]; then
		sqlite3 "$DB_FILE" "UPDATE plans SET source_file = '$(sql_escape "$spec_file")' WHERE id=$plan_id;"
	fi

	# Build plan file cache: extract all 'files' arrays from spec, deduplicate, resolve ~
	_build_plan_file_cache "$plan_id" "$effective_spec"

	log_info "Imported $wave_count waves, $total_tasks tasks"

	# Cleanup temp JSON if YAML was converted
	[[ "$effective_spec" != "$spec_file" ]] && rm -f "$effective_spec"
}

# Build ~/.claude/data/plan-{plan_id}-files.txt from spec.json
# Extracts all task 'files' arrays, deduplicates, resolves ~ to $HOME
_build_plan_file_cache() {
	local plan_id="$1"
	local spec_file="$2"
	local cache_dir="${HOME}/.claude/data"
	local cache_file="${cache_dir}/plan-${plan_id}-files.txt"

	mkdir -p "$cache_dir"

	# Extract all file paths from all waves/tasks, one per line, deduplicated
	jq -r '[.waves[].tasks[].files // []] | flatten | unique | .[]' "$spec_file" 2>/dev/null |
		sed "s|^~|${HOME}|g" \
			>"$cache_file"

	local file_count
	file_count=$(wc -l <"$cache_file" | tr -d ' ')
	log_info "File cache: $file_count paths -> $cache_file"
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

	# Locate spec file (try .yaml first, then .json) for requirements + user_request
	local spec_file=""
	if [[ -n "$md_path" ]]; then
		local spec_dir
		spec_dir="$(dirname "$(_expand_path "$md_path")")"
		# Try YAML first (new default), then JSON (legacy)
		for ext in yaml yml json; do
			local candidate="${spec_dir}/${plan_name}-spec.${ext}"
			if [[ -f "$candidate" ]]; then
				spec_file="$candidate"
				break
			fi
		done
	fi
	# Convert YAML spec to temp JSON for jq consumption
	local effective_render_spec="$spec_file"
	if [[ -n "$spec_file" && ("$spec_file" == *.yaml || "$spec_file" == *.yml) ]]; then
		effective_render_spec=$(yaml_to_json_temp "$spec_file") || effective_render_spec=""
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
		if [[ -n "$effective_render_spec" ]]; then
			jq -r '.user_request // "" | split("\n")[] | "> " + .' "$effective_render_spec" 2>/dev/null || echo "> [see source file]"
		elif [[ -n "$source_file" ]]; then
			echo "> [See source: $source_file]"
		fi
		echo ""

		echo "## CONSTRAINTS (NON-NEGOTIABLE)"
		echo "| ID | Constraint | Type | Verify |"
		echo "|----|-----------|------|--------|"
		if [[ -n "$effective_render_spec" ]]; then
			jq -r '.constraints // [] | .[] | "| \(.id) | \(.text) | \(.type) | \(.verify // "manual") |"' \
				"$effective_render_spec" 2>/dev/null || true
		fi
		echo ""

		echo "## FUNCTIONAL REQUIREMENTS"
		echo "| ID | Requirement | Wave | Verified |"
		echo "|----|-------------|------|----------|"
		if [[ -n "$effective_render_spec" ]]; then
			jq -r '.requirements // [] | .[] | "| \(.id) | \(.text) | \(.wave) | [ ] |"' \
				"$effective_render_spec" 2>/dev/null || true
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

	# Cleanup temp render spec if YAML was converted
	[[ -n "$effective_render_spec" && "$effective_render_spec" != "$spec_file" ]] && rm -f "$effective_render_spec"
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
			'output_data', COALESCE(t.output_data,''),
			'executor_agent', COALESCE(t.executor_agent,''),
			'wave_db_id', w.id, 'wave_id', w.wave_id,
			'wave_name', w.name,
			'wave_tasks_done', w.tasks_done,
			'wave_tasks_total', w.tasks_total
		)), '[]')
		FROM tasks t
		JOIN waves w ON t.wave_id_fk = w.id
		WHERE t.plan_id = $plan_id AND t.status IN ('pending', 'in_progress')
		ORDER BY w.position, t.task_id;")

	# Completed tasks output (ALL done tasks with output_data)
	local completed_output_json
	completed_output_json=$(sqlite3 "$DB_FILE" "
		SELECT COALESCE(json_group_array(json_object(
			'task_id', t.task_id,
			'wave_id', w.wave_id,
			'executor_agent', COALESCE(t.executor_agent,''),
			'output_data', COALESCE(t.output_data,'')
		)), '[]')
		FROM tasks t
		JOIN waves w ON t.wave_id_fk = w.id
		WHERE t.plan_id = $plan_id AND t.status = 'done' AND t.output_data IS NOT NULL AND t.output_data != ''
		ORDER BY w.position, t.task_id;")

	# Load constraints (ADR-054)
	local constraints_json
	constraints_json=$(sqlite3 "$DB_FILE" "SELECT COALESCE(constraints_json, '[]') FROM plans WHERE id=$plan_id;")

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
		--argjson completed_output "$completed_output_json" \
		--argjson constraints "$constraints_json" \
		--arg fw "$framework" \
		'. + {
			worktree_path: $wt,
			markdown_path: $md,
			pending_tasks: $tasks,
			completed_tasks_output: $completed_output,
			constraints: $constraints,
			framework: $fw
		}'
}
