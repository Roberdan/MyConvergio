#!/usr/bin/env bash
# Project audit check functions. Requires PROJECT_ROOT variable.
# Each function outputs JSON: {check, severity, pass, findings[]}
# Version: 1.0.0

_pa_json() {
	local check="$1" sev="$2" pass="$3" arr="$4"
	jq -n --arg c "$check" --arg s "$sev" --argjson p "$pass" --argjson f "$arr" \
		'{check:$c,severity:$s,pass:$p,findings:$f}'
}

_pa_finding() { jq -n --arg f "${1:-}" --arg b "$2" '{file:$f,body:$b}'; }

check_claude_md_exists() {
	local pass=true arr='[]'
	if [[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
		pass=false
		arr="[$(_pa_finding "" "CLAUDE.md not found in project root")]"
	fi
	_pa_json claude_md_exists P1 "$pass" "$arr"
}

check_claude_md_structure() {
	local pass=true findings=""
	[[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]] && { _pa_json claude_md_structure P2 true '[]'; return; }
	local f="$PROJECT_ROOT/CLAUDE.md"
	for section in "Build" "Test" "Lint"; do
		if ! grep -qiE "^#+.*${section}" "$f" 2>/dev/null; then
			findings="${findings}$(_pa_finding "$f" "Missing section: ${section}")
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	_pa_json claude_md_structure P2 "$pass" "$arr"
}

check_claude_md_line_count() {
	local pass=true arr='[]'
	[[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]] && { _pa_json claude_md_line_count P2 true '[]'; return; }
	local lines
	lines=$(wc -l < "$PROJECT_ROOT/CLAUDE.md" | tr -d ' ')
	if [[ "$lines" -gt 500 ]]; then
		pass=false
		arr="[$(_pa_finding "$PROJECT_ROOT/CLAUDE.md" "CLAUDE.md is ${lines} lines (target <500) — consider splitting")]"
	fi
	_pa_json claude_md_line_count P2 "$pass" "$arr"
}

check_agents_md_exists() {
	local pass=true arr='[]'
	if [[ ! -f "$PROJECT_ROOT/AGENTS.md" ]]; then
		pass=false
		arr="[$(_pa_finding "" "AGENTS.md not found — recommended for multi-agent workflows")]"
	fi
	_pa_json agents_md_exists P2 "$pass" "$arr"
}

check_gitignore_completeness() {
	local pass=true findings=""
	[[ ! -f "$PROJECT_ROOT/.gitignore" ]] && {
		_pa_json gitignore_completeness P1 false \
			"[$(_pa_finding "" ".gitignore not found")]"
		return
	}
	local gi="$PROJECT_ROOT/.gitignore"
	for pat in node_modules .env dist coverage __pycache__; do
		if [[ -d "$PROJECT_ROOT/$pat" || "$pat" == ".env" ]] && ! grep -qE "^/?${pat}" "$gi" 2>/dev/null; then
			findings="${findings}$(_pa_finding "$gi" "Missing pattern: ${pat}")
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	_pa_json gitignore_completeness P1 "$pass" "$arr"
}

check_gitignore_secrets() {
	local pass=true findings=""
	[[ ! -f "$PROJECT_ROOT/.gitignore" ]] && { _pa_json gitignore_secrets P2 true '[]'; return; }
	local gi="$PROJECT_ROOT/.gitignore"
	for pat in ".env.local" "*.pem" "*.key"; do
		if ! grep -qF "$pat" "$gi" 2>/dev/null; then
			findings="${findings}$(_pa_finding "$gi" "Consider adding: ${pat}")
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	_pa_json gitignore_secrets P2 "$pass" "$arr"
}

check_package_json_scripts() {
	local pass=true findings=""
	[[ ! -f "$PROJECT_ROOT/package.json" ]] && { _pa_json package_json_scripts P2 true '[]'; return; }
	local pj="$PROJECT_ROOT/package.json"
	for script in build test lint; do
		if ! jq -e ".scripts.${script}" "$pj" >/dev/null 2>&1; then
			findings="${findings}$(_pa_finding "$pj" "Missing script: ${script}")
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	_pa_json package_json_scripts P2 "$pass" "$arr"
}

check_ci_workflow_exists() {
	local pass=true arr='[]'
	if ! compgen -G "$PROJECT_ROOT/.github/workflows/*.yml" >/dev/null &&
		! compgen -G "$PROJECT_ROOT/.github/workflows/*.yaml" >/dev/null; then
		pass=false
		arr="[$(_pa_finding "" "No CI workflow found in .github/workflows/")]"
	fi
	_pa_json ci_workflow_exists P2 "$pass" "$arr"
}

check_a11y_config() {
	local pass=true arr='[]'
	[[ ! -f "$PROJECT_ROOT/package.json" ]] && { _pa_json a11y_config P3 true '[]'; return; }
	if ! jq -e '.devDependencies["eslint-plugin-jsx-a11y"] // .dependencies["eslint-plugin-jsx-a11y"]' \
		"$PROJECT_ROOT/package.json" >/dev/null 2>&1; then
		if jq -e '.dependencies.react // .devDependencies.react' "$PROJECT_ROOT/package.json" >/dev/null 2>&1; then
			pass=false
			arr="[$(_pa_finding "$PROJECT_ROOT/package.json" "React project without eslint-plugin-jsx-a11y")]"
		fi
	fi
	_pa_json a11y_config P3 "$pass" "$arr"
}

check_token_aware_comment_density() {
	local findings=""
	local src_files=()
	while IFS= read -r -d '' f; do
		src_files+=("$f")
	done < <(find "$PROJECT_ROOT" -maxdepth 4 \
		\( -name node_modules -o -name .git -o -name dist -o -name coverage -o -name __pycache__ -o -name vendor \) -prune -o \
		\( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -print0 2>/dev/null)
	[[ ${#src_files[@]} -eq 0 ]] && { _pa_json token_aware_comment_density P2 true '[]'; return; }
	for f in "${src_files[@]}"; do
		local total comment_lines pct comment_re
		total=$(awk 'END{print NR}' "$f" 2>/dev/null || echo 0)
		[[ "$total" -lt 10 ]] && continue
		# Language-aware comment detection
		if [[ "$f" =~ \.py$ ]]; then
			comment_re='^\s*#'
		elif [[ "$f" =~ \.(ts|tsx|js|jsx|mjs|cjs)$ ]]; then
			comment_re='^\s*(//|/\*|\*)'
		else
			continue  # unknown language → skip
		fi
		comment_lines=$(grep -cE "$comment_re" "$f" 2>/dev/null || echo 0)
		pct=$((comment_lines * 100 / total))
		if [[ "$pct" -gt 10 ]]; then
			local sev_label="P2"
			[[ "$pct" -gt 20 ]] && sev_label="P1"
			findings="${findings}$(jq -n --arg f "$f" --arg b "Comment density ${pct}% (${comment_lines}/${total}) — ${sev_label} threshold" \
				'{file:$f,body:$b}')
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true worst_sev="P2"
	if [[ $(echo "$arr" | jq 'length') -gt 0 ]]; then
		pass=false
		# Escalate to P1 if any file >20%
		echo "$arr" | jq -r '.[].body' 2>/dev/null | grep -q 'P1 threshold' && worst_sev="P1"
	fi
	_pa_json token_aware_comment_density "$worst_sev" "$pass" "$arr"
}

check_token_aware_doc_verbosity() {
	local findings=""
	local md_files=()
	while IFS= read -r -d '' f; do
		md_files+=("$f")
	done < <(find "$PROJECT_ROOT" -maxdepth 3 \
		\( -name node_modules -o -name .git -o -name dist \) -prune -o \
		-name '*.md' -print0 2>/dev/null)
	[[ ${#md_files[@]} -eq 0 ]] && { _pa_json token_aware_doc_verbosity P3 true '[]'; return; }
	for f in "${md_files[@]}"; do
		local lines words wpl
		lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
		[[ "$lines" -lt 5 ]] && continue
		words=$(wc -w < "$f" 2>/dev/null | tr -d ' ')
		wpl=$((words / lines))
		if [[ "$wpl" -gt 25 ]]; then
			findings="${findings}$(jq -n --arg f "$f" --arg b "Avg ${wpl} words/line (target <25) — consider tables/bullets" \
				'{file:$f,body:$b}')
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	_pa_json token_aware_doc_verbosity P3 "$pass" "$arr"
}

run_project_audit_checks() {
	PROJECT_ROOT="${1:-.}"
	local _no_cache="${2:-0}"
	: "$_no_cache"
	local checks='[]' result
	local check_fns=(
		check_claude_md_exists check_claude_md_structure check_claude_md_line_count check_agents_md_exists
		check_gitignore_completeness check_gitignore_secrets check_package_json_scripts check_ci_workflow_exists
		check_a11y_config check_token_aware_comment_density check_token_aware_doc_verbosity
	)
	for fn in "${check_fns[@]}"; do
		result="$($fn)"
		checks="$(jq -c --argjson item "$result" '. + [$item]' <<<"$checks")"
	done
	echo "$checks"
}

project_audit_checks_json() {
	run_project_audit_checks "$@"
}
