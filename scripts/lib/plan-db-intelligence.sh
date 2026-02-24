#!/bin/bash
# Plan DB Intelligence - Learnings, reviews, assessments, token estimates
# Sourced by plan-db.sh

# Version: 1.0.0

# --- Learnings ---

cmd_add_learning() {
	local plan_id="${1:?plan_id required}"
	local category="${2:?category required}"
	local severity="${3:?severity required}"
	local title="${4:?title required}"
	shift 4
	local detail="" task_id="" wave_id="" tags="" actionable=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--detail) detail="$2"; shift 2 ;;
		--task-id) task_id="$2"; shift 2 ;;
		--wave-id) wave_id="$2"; shift 2 ;;
		--tags) tags="$2"; shift 2 ;;
		--actionable) actionable=1; shift ;;
		*) shift ;;
		esac
	done

	local safe_title="$(sql_escape "$title")"
	local safe_detail="$(sql_escape "$detail")"
	local safe_tags="$(sql_escape "$tags")"
	local safe_task_id="$(sql_escape "$task_id")"
	local safe_wave_id="$(sql_escape "$wave_id")"

	local id=$(sqlite3 "$DB_FILE" "
		INSERT INTO plan_learnings (plan_id, category, severity, title, detail, task_id, wave_id, tags, actionable)
		VALUES ($plan_id, '$category', '$severity', '$safe_title', '$safe_detail', '$safe_task_id', '$safe_wave_id', '$safe_tags', $actionable);
		SELECT last_insert_rowid();
	")
	echo "[OK] Learning #$id added (plan=$plan_id, severity=$severity)"
}

cmd_get_learnings() {
	local plan_id="${1:?plan_id required}"
	shift
	local category="" severity="" actionable_only=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--category) category="$2"; shift 2 ;;
		--severity) severity="$2"; shift 2 ;;
		--actionable) actionable_only=1; shift ;;
		*) shift ;;
		esac
	done

	local where="WHERE plan_id = $plan_id"
	[[ -n "$category" ]] && where="$where AND category = '$(sql_escape "$category")'"
	[[ -n "$severity" ]] && where="$where AND severity = '$(sql_escape "$severity")'"
	[[ "$actionable_only" == "1" ]] && where="$where AND actionable = 1"

	sqlite3 -header -column "$DB_FILE" "
		SELECT id, category, severity, title, actionable,
			CASE WHEN action_taken IS NOT NULL THEN 'done' ELSE 'pending' END as action_status
		FROM plan_learnings $where
		ORDER BY CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END, created_at DESC;
	"
}

cmd_get_actionable_learnings() {
	local plan_id="${1:-}"
	local where="WHERE actionable = 1 AND action_taken IS NULL"
	[[ -n "$plan_id" ]] && where="$where AND plan_id = $plan_id"

	sqlite3 -header -column "$DB_FILE" "
		SELECT id, plan_id, category, severity, title, task_id, wave_id
		FROM plan_learnings $where
		ORDER BY CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END, created_at DESC;
	"
}

# --- Reviews ---

cmd_add_review() {
	local plan_id="${1:?plan_id required}"
	local reviewer="${2:?reviewer_agent required}"
	local verdict="${3:?verdict required (APPROVED|NEEDS_REVISION)}"
	shift 3
	local fxx_score="" completeness="" suggestions="" gaps="" risk="" raw=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--fxx-score) fxx_score="$2"; shift 2 ;;
		--completeness) completeness="$2"; shift 2 ;;
		--suggestions) suggestions="$2"; shift 2 ;;
		--gaps) gaps="$2"; shift 2 ;;
		--risk) risk="$2"; shift 2 ;;
		--raw-report) raw="$2"; shift 2 ;;
		*) shift ;;
		esac
	done

	local safe_reviewer="$(sql_escape "$reviewer")"
	local safe_suggestions="$(sql_escape "$suggestions")"
	local safe_gaps="$(sql_escape "$gaps")"
	local safe_risk="$(sql_escape "$risk")"
	local safe_raw="$(sql_escape "$raw")"

	local id=$(sqlite3 "$DB_FILE" "
		INSERT INTO plan_reviews (plan_id, reviewer_agent, verdict, fxx_coverage_score, completeness_score, suggestions, gaps, risk_assessment, raw_report)
		VALUES ($plan_id, '$safe_reviewer', '$verdict',
			$([ -n "$fxx_score" ] && echo "$fxx_score" || echo "NULL"),
			$([ -n "$completeness" ] && echo "$completeness" || echo "NULL"),
			'$safe_suggestions', '$safe_gaps', '$safe_risk', '$safe_raw');
		SELECT last_insert_rowid();
	")
	echo "[OK] Review #$id added (plan=$plan_id, verdict=$verdict, by=$reviewer)"
}

# --- Business Assessments ---

cmd_add_assessment() {
	local plan_id="${1:?plan_id required}"
	shift
	local effort="" complexity="" value="" risk="" roi="" by=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--effort-days) effort="$2"; shift 2 ;;
		--complexity) complexity="$2"; shift 2 ;;
		--value) value="$2"; shift 2 ;;
		--risk) risk="$2"; shift 2 ;;
		--roi) roi="$2"; shift 2 ;;
		--by) by="$2"; shift 2 ;;
		*) shift ;;
		esac
	done

	local safe_risk="$(sql_escape "$risk")"
	local safe_by="$(sql_escape "$by")"

	local id=$(sqlite3 "$DB_FILE" "
		INSERT INTO plan_business_assessments (plan_id, traditional_effort_days, complexity_rating, business_value_score, risk_assessment, roi_projection, assessed_by)
		VALUES ($plan_id,
			$([ -n "$effort" ] && echo "$effort" || echo "NULL"),
			$([ -n "$complexity" ] && echo "$complexity" || echo "NULL"),
			$([ -n "$value" ] && echo "$value" || echo "NULL"),
			'$safe_risk',
			$([ -n "$roi" ] && echo "$roi" || echo "NULL"),
			'$safe_by');
		SELECT last_insert_rowid();
	")
	echo "[OK] Assessment #$id added (plan=$plan_id)"
}

# --- Actuals ---

cmd_add_actuals() {
	local plan_id="${1:?plan_id required}"
	shift
	local tokens="" cost="" ai_min="" user_min="" total="" revised="" rejection="" roi=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--tokens) tokens="$2"; shift 2 ;;
		--cost) cost="$2"; shift 2 ;;
		--ai-minutes) ai_min="$2"; shift 2 ;;
		--user-minutes) user_min="$2"; shift 2 ;;
		--total-tasks) total="$2"; shift 2 ;;
		--revised-by-thor) revised="$2"; shift 2 ;;
		--rejection-rate) rejection="$2"; shift 2 ;;
		--roi) roi="$2"; shift 2 ;;
		*) shift ;;
		esac
	done

	local id=$(sqlite3 "$DB_FILE" "
		INSERT OR REPLACE INTO plan_actuals (plan_id, total_tokens, total_cost_usd, ai_duration_minutes, user_spec_minutes, total_tasks, tasks_revised_by_thor, thor_rejection_rate, actual_roi)
		VALUES ($plan_id,
			$([ -n "$tokens" ] && echo "$tokens" || echo "NULL"),
			$([ -n "$cost" ] && echo "$cost" || echo "NULL"),
			$([ -n "$ai_min" ] && echo "$ai_min" || echo "NULL"),
			$([ -n "$user_min" ] && echo "$user_min" || echo "NULL"),
			$([ -n "$total" ] && echo "$total" || echo "NULL"),
			$([ -n "$revised" ] && echo "$revised" || echo "NULL"),
			$([ -n "$rejection" ] && echo "$rejection" || echo "NULL"),
			$([ -n "$roi" ] && echo "$roi" || echo "NULL"));
		SELECT last_insert_rowid();
	")
	echo "[OK] Actuals #$id recorded (plan=$plan_id)"
}

# --- Token Estimates ---

cmd_estimate_tokens() {
	local plan_id="${1:?plan_id required}"
	local scope="${2:?scope required (task|wave|plan)}"
	local scope_id="${3:?scope_id required}"
	local est_tokens="${4:?estimated_tokens required}"
	shift 4
	local est_cost="" model="" agent="" notes=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--cost) est_cost="$2"; shift 2 ;;
		--model) model="$2"; shift 2 ;;
		--agent) agent="$2"; shift 2 ;;
		--notes) notes="$2"; shift 2 ;;
		*) shift ;;
		esac
	done

	local safe_scope_id="$(sql_escape "$scope_id")"
	local safe_model="$(sql_escape "$model")"
	local safe_agent="$(sql_escape "$agent")"
	local safe_notes="$(sql_escape "$notes")"

	local id=$(sqlite3 "$DB_FILE" "
		INSERT INTO plan_token_estimates (plan_id, scope, scope_id, estimated_tokens, estimated_cost_usd, model, executor_agent, notes)
		VALUES ($plan_id, '$scope', '$safe_scope_id', $est_tokens,
			$([ -n "$est_cost" ] && echo "$est_cost" || echo "NULL"),
			'$safe_model', '$safe_agent', '$safe_notes');
		SELECT last_insert_rowid();
	")
	echo "[OK] Estimate #$id created (plan=$plan_id, scope=$scope, tokens=$est_tokens)"
}

cmd_update_token_actuals() {
	local estimate_id="${1:?estimate_id required}"
	local actual_tokens="${2:?actual_tokens required}"
	shift 2
	local actual_cost=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--cost) actual_cost="$2"; shift 2 ;;
		*) shift ;;
		esac
	done

	sqlite3 "$DB_FILE" "
		UPDATE plan_token_estimates
		SET actual_tokens = $actual_tokens,
			actual_cost_usd = $([ -n "$actual_cost" ] && echo "$actual_cost" || echo "NULL"),
			variance_pct = CASE WHEN estimated_tokens > 0
				THEN ROUND(($actual_tokens - estimated_tokens) * 100.0 / estimated_tokens, 1)
				ELSE NULL END,
			completed_at = CURRENT_TIMESTAMP
		WHERE id = $estimate_id;
	"
	echo "[OK] Estimate #$estimate_id updated (actual=$actual_tokens tokens)"
}

cmd_calibrate_estimates() {
	local model="${1:-}"
	local where=""
	[[ -n "$model" ]] && where="WHERE model = '$(sql_escape "$model")'"
	[[ -z "$where" ]] && where="WHERE actual_tokens IS NOT NULL" || where="$where AND actual_tokens IS NOT NULL"

	sqlite3 -header -column "$DB_FILE" "
		SELECT model,
			COUNT(*) as samples,
			ROUND(AVG(estimated_tokens), 0) as avg_estimated,
			ROUND(AVG(actual_tokens), 0) as avg_actual,
			ROUND(AVG(variance_pct), 1) as avg_variance_pct,
			ROUND(AVG(ABS(variance_pct)), 1) as avg_abs_error_pct
		FROM plan_token_estimates
		$where
		GROUP BY model
		ORDER BY avg_abs_error_pct;
	"
}
