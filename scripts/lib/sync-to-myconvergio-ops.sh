#!/usr/bin/env bash
# sync-to-myconvergio-ops.sh - File sync operations for MyConvergio
# Extracted from sync-to-myconvergio.sh for modularization
# Version: 1.0.0

# ============================================================================
# Blocklist checking
# ============================================================================
is_blocked() {
	local rel_path="$1" category="$2"
	local entry
	for entry in "${BLOCKLIST[@]}"; do
		local cat="${entry%%:*}"
		local pattern="${entry#*:}"
		if [[ "$category" == "$cat" ]] && [[ "$rel_path" == "$pattern"* ]]; then
			return 0
		fi
	done
	return 1
}

# ============================================================================
# Sanitization checking
# ============================================================================
check_sanitization() {
	local file="$1"
	local warnings=0
	for pattern in "${PERSONAL_PATTERNS[@]}"; do
		if grep -q "$pattern" "$file" 2>/dev/null; then
			echo -e "    ${YELLOW}⚠ Contains: $pattern${NC}"
			warnings=$((warnings + 1))
		fi
	done
	return $warnings
}

# ============================================================================
# Directory synchronization
# ============================================================================
sync_dir() {
	local src_base="$1"
	local tgt_base="$2"
	local label="$3"
	local cat_key="${4:-NONE}"

	if [ ! -d "$src_base" ]; then
		echo -e "${YELLOW}SKIP: $label (source not found: $src_base)${NC}"
		return
	fi

	echo -e "\n${CYAN}=== $label ===${NC}"
	echo -e "  Source: $src_base"
	echo -e "  Target: $tgt_base"

	while IFS= read -r src_file; do
		local rel_path="${src_file#$src_base/}"

		# Skip non-content files
		[[ "$rel_path" == .* ]] && continue
		[[ "$rel_path" == "logs/"* ]] && continue
		[[ "$(basename "$rel_path")" == ".DS_Store" ]] && continue

		# Check blocklist
		if is_blocked "$rel_path" "$cat_key"; then
			BLOCKED=$((BLOCKED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  ${RED}BLOCKED${NC}: $rel_path"
			fi
			continue
		fi

		local tgt_file="$tgt_base/$rel_path"

		# Sanitization check
		local san_ok=true
		if ! check_sanitization "$src_file" 2>/dev/null; then
			san_ok=false
			SANITIZE_WARN=$((SANITIZE_WARN + 1))
		fi

		if [ ! -f "$tgt_file" ]; then
			echo -e "  ${GREEN}NEW${NC}: $rel_path"
			NEW=$((NEW + 1))
			if [ "$DRY_RUN" = false ]; then
				mkdir -p "$(dirname "$tgt_file")"
				cp "$src_file" "$tgt_file"
			fi
		elif ! diff -q "$src_file" "$tgt_file" >/dev/null 2>&1; then
			echo -e "  ${YELLOW}UPDATED${NC}: $rel_path"
			UPDATED=$((UPDATED + 1))
			if [ "$DRY_RUN" = false ]; then
				cp "$src_file" "$tgt_file"
			fi
			if [ "$VERBOSE" = true ]; then
				diff --brief "$tgt_file" "$src_file" 2>/dev/null || true
			fi
		else
			UNCHANGED=$((UNCHANGED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  UNCHANGED: $rel_path"
			fi
		fi
	done < <(find "$src_base" -type f | sort)
}

# ============================================================================
# Copilot agents synchronization
# ============================================================================
sync_copilot() {
	local src_base="$SOURCE_DIR/copilot-agents"
	local tgt_base="$TARGET_REPO/copilot-agents"

	if [ ! -d "$src_base" ]; then
		echo -e "${YELLOW}SKIP: copilot-agents (source not found)${NC}"
		return
	fi

	echo -e "\n${CYAN}=== Copilot CLI Agents ===${NC}"
	echo -e "  Source: $src_base"
	echo -e "  Target: $tgt_base"

	for src_file in "$src_base"/*.agent.md; do
		[ -f "$src_file" ] || continue
		local filename
		filename=$(basename "$src_file")
		local tgt_file="$tgt_base/$filename"

		if [ ! -f "$tgt_file" ]; then
			echo -e "  ${GREEN}NEW${NC}: $filename"
			NEW=$((NEW + 1))
			if [ "$DRY_RUN" = false ]; then
				mkdir -p "$tgt_base"
				cp "$src_file" "$tgt_file"
			fi
		elif ! diff -q "$src_file" "$tgt_file" >/dev/null 2>&1; then
			echo -e "  ${YELLOW}UPDATED${NC}: $filename"
			UPDATED=$((UPDATED + 1))
			if [ "$DRY_RUN" = false ]; then
				cp "$src_file" "$tgt_file"
			fi
		else
			UNCHANGED=$((UNCHANGED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  UNCHANGED: $filename"
			fi
		fi
	done
}
