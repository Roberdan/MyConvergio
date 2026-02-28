#!/usr/bin/env bash
# Requires CODE_FILES array. Each function outputs JSON: {check, severity, pass, findings[]}
# Version: 1.2.0

check_unguarded_json_parse() {
	local findings
	findings=$(grep -rEnH '(JSON\.parse\(|json\.loads\()' "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		local start=$((line_num - 5))
		[[ $start -lt 1 ]] && start=1
		local context
		context=$(sed -n "${start},${line_num}p" "$file" 2>/dev/null || true)
		if ! echo "$context" | grep -qE '(try\s*\{|try:|except|catch)'; then
			jq -n --arg f "$file" --arg l "$line_num" --arg b "$match" \
				'{file:$f, line:($l|tonumber), body:($b|.[0:200])}'
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "unguarded_json_parse" --arg sev "P1" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_unguarded_method_call() {
	local findings
	findings=$(grep -rEnH '\.(toFixed|toString|toUpperCase|toLowerCase|trim|split)\(' "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		local start=$((line_num - 3))
		[[ $start -lt 1 ]] && start=1
		local context
		context=$(sed -n "${start},${line_num}p" "$file" 2>/dev/null || true)
		if ! echo "$context" | grep -qE '(\?\.|!= ?null|!== ?null|!= ?undefined|!== ?undefined|if\s*\(|&&)'; then
			jq -n --arg f "$file" --arg l "$line_num" --arg b "$match" \
				'{file:$f, line:($l|tonumber), body:($b|.[0:200])}'
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "unguarded_method_call" --arg sev "P1" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_react_lazy_named_export() {
	local findings
	findings=$(grep -rEnH 'React\.lazy\(\(\) *=> *import\(' "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file import_path
		file=$(echo "$match" | cut -d: -f1)
		import_path=$(echo "$match" | grep -oP "import\(['\"]([^'\"]+)" | sed "s/import(['\"]//")
		if [[ -n "$import_path" ]]; then
			local dir resolved
			dir=$(dirname "$file")
			resolved=""
			for ext in .tsx .ts .jsx .js; do
				if [[ -f "${dir}/${import_path}${ext}" ]]; then
					resolved="${dir}/${import_path}${ext}"
					break
				fi
			done
			if [[ -n "$resolved" ]] && ! grep -q 'export default' "$resolved" 2>/dev/null; then
				local line_num
				line_num=$(echo "$match" | cut -d: -f2)
				jq -n --arg f "$file" --arg l "$line_num" \
					--arg b "React.lazy imports $import_path which has no default export" \
					'{file:$f, line:($l|tonumber), body:$b}'
			fi
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "react_lazy_named_export" --arg sev "P1" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_load_all_paginate() {
	local findings
	findings=$(grep -rEnH '(\.findMany\(\)|\.all\(\)|SELECT \*)' "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		local end=$((line_num + 5))
		local after
		after=$(sed -n "${line_num},${end}p" "$file" 2>/dev/null || true)
		if echo "$after" | grep -qE '(\.slice\(|\.splice\(|\[.*:.*\]|\.substring\(|offset|limit)'; then
			jq -n --arg f "$file" --arg l "$line_num" \
				--arg b "Load-all + client-side pagination detected" \
				'{file:$f, line:($l|tonumber), body:$b}'
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "load_all_paginate" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_duplicate_class_names() {
	local findings
	findings=$(grep -rEhH '(^export )?(class |function |const \w+ ?= ?\(|interface |type |enum )' \
		"${CODE_FILES[@]}" 2>/dev/null |
		sed 's/:.*//' | sort | uniq -d | while IFS= read -r dup; do
		local files_with
		files_with=$(grep -rlE "(class |function |const |interface |type |enum )${dup}" "${CODE_FILES[@]}" 2>/dev/null | sort -u)
		local count
		count=$(echo "$files_with" | grep -c . 2>/dev/null || echo 0)
		if [[ "$count" -gt 1 ]]; then
			jq -n --arg b "Duplicate name '$dup' in multiple files" \
				'{file:null, line:null, body:$b}'
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "duplicate_class_names" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_unused_parameters() {
	local ts_files=()
	for f in "${CODE_FILES[@]}"; do
		[[ "$f" =~ \.(ts|tsx|js|jsx)$ ]] && ts_files+=("$f")
	done
	[[ ${#ts_files[@]} -eq 0 ]] && {
		jq -n '{"check":"unused_parameters","severity":"P2","pass":true,"findings":[]}'
		return
	}
	local findings
	findings=$(grep -rEnH '(function \w+|const \w+ *= *)\(([^)]+)\)' "${ts_files[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num params
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		params=$(echo "$match" | grep -oP '\(([^)]+)\)' | tr ',' '\n' | grep -oP '\b\w+' | grep -v -E '^(const|let|var|function|async|await|return|type|interface|string|number|boolean|any|void|null|undefined|Promise|Array|Record|Map|Set)$')
		for param in $params; do
			[[ "$param" =~ ^_ ]] && continue
			[[ ${#param} -lt 2 ]] && continue
			local end=$((line_num + 30))
			local body
			body=$(sed -n "$((line_num + 1)),${end}p" "$file" 2>/dev/null || true)
			if ! echo "$body" | grep -qw "$param"; then
				jq -n --arg f "$file" --arg l "$line_num" \
					--arg b "Parameter '$param' appears unused" \
					'{file:$f, line:($l|tonumber), body:$b}'
			fi
		done
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "unused_parameters" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_insecure_file_write() {
	local findings
	findings=$(grep -rEnH "(open\([^)]*,[[:space:]]*['\"]w['\"]|writeFileSync\()" "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num line_content
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		line_content=$(echo "$match" | cut -d: -f3-)
		if ! echo "$line_content" | grep -qE '(mode|0o[0-9]{3}|0[0-9]{3}|permissions|chmod)'; then
			if echo "$line_content" | grep -qEi '(\.env|config|secret|key|credential|token|password|\.pem|\.key)'; then
				jq -n --arg f "$file" --arg l "$line_num" \
					--arg b "File write without explicit mode on sensitive path" \
					'{file:$f, line:($l|tonumber), body:$b}'
			fi
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "insecure_file_write" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_missing_error_boundary() {
	local findings
	findings=$(grep -rEnH '(fetch\(|axios\.|\.get\(|\.post\(|\.put\(|\.delete\(|\.patch\()' "${CODE_FILES[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		local start=$((line_num - 5))
		[[ $start -lt 1 ]] && start=1
		local end=$((line_num + 3))
		local context
		context=$(sed -n "${start},${end}p" "$file" 2>/dev/null || true)
		if ! echo "$context" | grep -qE '(try\s*\{|\.catch\(|catch\s*\(|except|\.then\(.*\.catch)'; then
			jq -n --arg f "$file" --arg l "$line_num" --arg b "$match" \
				'{file:$f, line:($l|tonumber), body:($b|.[0:200])}'
		fi
	done || true)
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "missing_error_boundary" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_comment_density() {
	local findings=""
	for f in "${CODE_FILES[@]}"; do
		local total comment_lines pct
		total=$(awk 'END{print NR}' "$f" 2>/dev/null || echo 0)
		[[ "$total" -lt 10 ]] && continue
		comment_lines=$(grep -cE '^\s*(#[^!]|//|/\*|\*)' "$f" 2>/dev/null || echo 0)
		pct=$((comment_lines * 100 / total))
		if [[ "$pct" -gt 20 ]]; then
			findings="${findings}$(jq -n --arg f "$f" --arg b "Comment density ${pct}% (${comment_lines}/${total}) — target <5%" '{file:$f, line:null, body:$b}')
"
		fi
	done
	local arr
	arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true
	[[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "comment_density" --arg sev "P3" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_silent_degradation() {
	local tsx_files=()
	for f in "${CODE_FILES[@]}"; do [[ "$f" =~ \.tsx$ ]] && tsx_files+=("$f"); done
	[[ ${#tsx_files[@]} -eq 0 ]] && { jq -n '{"check":"silent_degradation","severity":"P2","pass":true,"findings":[]}'; return; }
	local findings
	findings=$(grep -rEnH 'return null|return undefined' "${tsx_files[@]}" 2>/dev/null | while IFS= read -r match; do
		local file line_num
		file=$(echo "$match" | cut -d: -f1)
		line_num=$(echo "$match" | cut -d: -f2)
		local start=$((line_num - 3)); [[ $start -lt 1 ]] && start=1
		local ctx; ctx=$(sed -n "${start},${line_num}p" "$file" 2>/dev/null || true)
		if echo "$ctx" | grep -qE '(\.length\s*(===|==)\s*0|!.*data|isEmpty|\.length\s*<\s*1)'; then
			jq -n --arg f "$file" --arg l "$line_num" \
				--arg b "Silent degradation: return null on empty data — use fail-loud pattern" \
				'{file:$f, line:($l|tonumber), body:$b}'
		fi
	done || true)
	local arr; arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true; [[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "silent_degradation" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}

check_orphan_exports() {
	local ts_files=()
	for f in "${CODE_FILES[@]}"; do [[ "$f" =~ \.(ts|tsx)$ ]] && ts_files+=("$f"); done
	[[ ${#ts_files[@]} -eq 0 ]] && { jq -n '{"check":"orphan_exports","severity":"P2","pass":true,"findings":[]}'; return; }
	local findings=""
	for f in "${ts_files[@]}"; do
		[[ "$f" =~ (index\.ts|\.test\.|\.spec\.|main\.tsx|app\.tsx|app\.py)$ ]] && continue
		local exports; exports=$(grep -oE 'export (function|const|class|type|interface) ([A-Z][A-Za-z0-9]+)' "$f" 2>/dev/null | awk '{print $3}' || true)
		for exp in $exports; do
			[[ -z "$exp" ]] && continue
			local dir; dir=$(dirname "$f")
			local imports; imports=$(grep -rl "$exp" "$dir" --include='*.ts' --include='*.tsx' 2>/dev/null | grep -v "$f" | grep -v '\.test\.' | grep -v '\.spec\.' | head -1 || true)
			if [[ -z "$imports" ]]; then
				local line; line=$(grep -n "export.*$exp" "$f" 2>/dev/null | head -1 | cut -d: -f1)
				findings="${findings}$(jq -n --arg f "$f" --arg l "${line:-0}" \
					--arg b "Orphan export: '$exp' has no imports outside its own file" \
					'{file:$f, line:($l|tonumber), body:$b}')
"
			fi
		done
	done
	local arr; arr=$(echo "$findings" | jq -s '.' 2>/dev/null || echo '[]')
	local pass=true; [[ $(echo "$arr" | jq 'length') -gt 0 ]] && pass=false
	jq -n --arg check "orphan_exports" --arg sev "P2" \
		--argjson pass "$pass" --argjson findings "$arr" \
		'{check:$check, severity:$sev, pass:$pass, findings:$findings}'
}
