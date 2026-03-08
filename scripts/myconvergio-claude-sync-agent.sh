#!/usr/bin/env bash
set -euo pipefail
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MYCONVERGIO_HOME="${MYCONVERGIO_HOME:-$HOME/GitHub/MyConvergio}"
BASELINE_FILE="$MYCONVERGIO_HOME/.claude-snapshot-baseline.json"
TARGET_CLAUDE_DIR="$MYCONVERGIO_HOME/.claude"
MAX_STALE_PR_DAYS="${MAX_STALE_PR_DAYS:-7}"
INTERACTIVE=false
DRY_RUN=false
REPORT_ONLY=false

TMP_DIR="$(mktemp -d)"
CURRENT_SNAPSHOT="$TMP_DIR/current-snapshot.json"
COMBINED_JSON="$TMP_DIR/combined.json"
PR_BODY_FILE="$TMP_DIR/pr-body.md"

NEW_RULES=() MOD_RULES=() DEL_RULES=()
NEW_HOOKS=() MOD_HOOKS=() DEL_HOOKS=()
NEW_COMMANDS=() MOD_COMMANDS=() DEL_COMMANDS=()
NEW_SKILLS=() MOD_SKILLS=() DEL_SKILLS=()
NEW_AGENTS=() MOD_AGENTS=() DEL_AGENTS=()
APPLIED_FILES=()

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log() { printf '[claude-sync] %s\n' "$*"; }
die() { printf '[claude-sync] ERROR: %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interactive) INTERACTIVE=true ;;
    --dry-run) DRY_RUN=true ;;
    --report-only) REPORT_ONLY=true ;;
    -h|--help) echo "Usage: $0 [--interactive] [--dry-run] [--report-only]"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done

[[ "$REPORT_ONLY" == true ]] && DRY_RUN=true

for cmd in jq git gh shasum awk find sort sed diff mktemp; do
  require_cmd "$cmd"
done
[[ -d "$CLAUDE_HOME" ]] || die "CLAUDE_HOME not found: $CLAUDE_HOME"
[[ -d "$MYCONVERGIO_HOME/.git" ]] || die "MyConvergio repo not found: $MYCONVERGIO_HOME"
[[ -f "$BASELINE_FILE" ]] || die "Baseline missing: $BASELINE_FILE"

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
extract_version_line() { [[ -f "$1" ]] && sed -n '1p' "$1" || echo ""; }

build_category_json() {
  local dir="$1"
  local list_file="$2"
  local abs rel
  : > "$list_file"
  if [[ -d "$CLAUDE_HOME/$dir" ]]; then
    find "$CLAUDE_HOME/$dir" -type f | sort > "$list_file"
  fi
  while IFS= read -r abs; do
    [[ -z "$abs" ]] && continue
    rel="${abs#"$CLAUDE_HOME"/}"
    jq -n --arg path "$rel" --arg sha "$(sha256_file "$abs")" '{path:$path,sha256:$sha}'
  done < "$list_file" | jq -s '.'
}

create_snapshot() {
  local rules_json hooks_json commands_json skills_json agents_json
  rules_json="$(build_category_json "rules" "$TMP_DIR/rules.lst")"
  hooks_json="$(build_category_json "hooks" "$TMP_DIR/hooks.lst")"
  commands_json="$(build_category_json "commands" "$TMP_DIR/commands.lst")"
  skills_json="$(build_category_json "skills" "$TMP_DIR/skills.lst")"
  agents_json="$(build_category_json "agents" "$TMP_DIR/agents.lst")"
  jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg claude_git_sha "$(git -C "$CLAUDE_HOME" rev-parse --short HEAD 2>/dev/null || echo "unknown")" \
    --arg claude_md_version "$(extract_version_line "$CLAUDE_HOME/CLAUDE.md")" \
    --arg agents_md_version "$(extract_version_line "$CLAUDE_HOME/AGENTS.md")" \
    --arg claude_sha "$(sha256_file "$CLAUDE_HOME/CLAUDE.md")" \
    --arg agents_sha "$(sha256_file "$CLAUDE_HOME/AGENTS.md")" \
    --argjson rules "$rules_json" \
    --argjson hooks "$hooks_json" \
    --argjson commands "$commands_json" \
    --argjson skills "$skills_json" \
    --argjson agents "$agents_json" \
    '{
      timestamp:$timestamp, claude_git_sha:$claude_git_sha,
      claude_md_version:$claude_md_version, agents_md_version:$agents_md_version,
      rules:$rules, hooks:$hooks, commands:$commands, skills:$skills, agents:$agents,
      docs:[{path:"CLAUDE.md",sha256:$claude_sha},{path:"AGENTS.md",sha256:$agents_sha}]
    }' > "$CURRENT_SNAPSHOT"
}

append_array() {
  local var_name="$1"
  shift
  eval "$var_name+=(\"\$1\")"
}

collect_diffs() {
  local category="$1" new_var="$2" mod_var="$3" del_var="$4"
  local entry
  while IFS= read -r entry; do [[ -n "$entry" ]] && append_array "$new_var" "$entry"; done < <(
    jq -r --arg c "$category" '
      def mapify(a): reduce a[] as $i ({}; .[$i.path]=$i.sha256);
      (mapify(.baseline[$c] // [])) as $b | (mapify(.current[$c] // [])) as $n
      | ($n|keys[]) | select(($b[.] // "") == "")
    ' "$COMBINED_JSON"
  )
  while IFS= read -r entry; do [[ -n "$entry" ]] && append_array "$mod_var" "$entry"; done < <(
    jq -r --arg c "$category" '
      def mapify(a): reduce a[] as $i ({}; .[$i.path]=$i.sha256);
      (mapify(.baseline[$c] // [])) as $b | (mapify(.current[$c] // [])) as $n
      | ($n|keys[]) | select(($b[.] // "") != "" and $b[.] != $n[.])
    ' "$COMBINED_JSON"
  )
  while IFS= read -r entry; do [[ -n "$entry" ]] && append_array "$del_var" "$entry"; done < <(
    jq -r --arg c "$category" '
      def mapify(a): reduce a[] as $i ({}; .[$i.path]=$i.sha256);
      (mapify(.baseline[$c] // [])) as $b | (mapify(.current[$c] // [])) as $n
      | ($b|keys[]) | select(($n[.] // "") == "")
    ' "$COMBINED_JSON"
  )
}

prompt_yes() {
  local msg="$1" reply
  [[ "$INTERACTIVE" != true ]] && return 0
  printf '%s [y/N]: ' "$msg"
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

adapt_and_copy() {
  local rel="$1"
  local src="$CLAUDE_HOME/$rel"
  local dst="$TARGET_CLAUDE_DIR/$rel"
  [[ -f "$src" ]] || die "Missing source file: $src"
  [[ "$DRY_RUN" == true ]] && { log "DRY-RUN copy $rel -> .claude/$rel"; return 0; }
  mkdir -p "$(dirname "$dst")"
  awk -v home="$HOME" '
    {
      gsub(home "/.claude", "${MYCONVERGIO_HOME}/.claude");
      gsub("~/.claude", "${MYCONVERGIO_HOME}/.claude");
      gsub("\\$HOME/.claude", "${MYCONVERGIO_HOME}/.claude");
      print
    }' "$src" > "$dst"
  APPLIED_FILES+=(".claude/$rel")
}

show_diff_for_rule() {
  local rel="$1"
  local src="$CLAUDE_HOME/$rel"
  local dst="$TARGET_CLAUDE_DIR/$rel"
  [[ -f "$src" ]] || return 0
  if [[ -f "$dst" ]]; then
    diff -u "$dst" "$src" || true
  else
    diff -u /dev/null "$src" || true
  fi
}

report_category() {
  local name="$1"; shift
  local -a items=("$@")
  printf '\n%s (%s)\n' "$name" "${#items[@]}"
  ((${#items[@]} == 0)) && printf '  - none\n'
  for item in "${items[@]}"; do printf '  - %s\n' "$item"; done
}

close_stale_prs() {
  local stale_numbers
  stale_numbers="$(gh pr list --repo Roberdan/MyConvergio --state open --limit 100 --json number,headRefName,updatedAt | jq -r \
    --argjson days "$MAX_STALE_PR_DAYS" \
    '.[] | select((.headRefName // "") | startswith("sync/claude-alignment-")) | select((.updatedAt | fromdateiso8601) < (now - ($days*86400))) | .number')"
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    log "Closing stale PR #$n"
    gh pr close --repo Roberdan/MyConvergio "$n" --comment "Closing stale sync PR older than ${MAX_STALE_PR_DAYS} days." >/dev/null || true
  done <<< "$stale_numbers"
}

create_snapshot
jq -n --slurpfile baseline "$BASELINE_FILE" --slurpfile current "$CURRENT_SNAPSHOT" '{baseline:$baseline[0], current:$current[0]}' > "$COMBINED_JSON"
collect_diffs "rules" "NEW_RULES" "MOD_RULES" "DEL_RULES"
collect_diffs "hooks" "NEW_HOOKS" "MOD_HOOKS" "DEL_HOOKS"
collect_diffs "commands" "NEW_COMMANDS" "MOD_COMMANDS" "DEL_COMMANDS"
collect_diffs "skills" "NEW_SKILLS" "MOD_SKILLS" "DEL_SKILLS"
collect_diffs "agents" "NEW_AGENTS" "MOD_AGENTS" "DEL_AGENTS"

for rel in "${MOD_RULES[@]}"; do show_diff_for_rule "$rel"; done
for rel in "${NEW_RULES[@]}" "${MOD_RULES[@]}" "${NEW_HOOKS[@]}" "${MOD_HOOKS[@]}" "${NEW_COMMANDS[@]}" "${MOD_COMMANDS[@]}" "${NEW_SKILLS[@]}" "${MOD_SKILLS[@]}"; do
  [[ -z "$rel" ]] && continue
  prompt_yes "Apply $rel ?" && adapt_and_copy "$rel"
done

report_category "New rules" "${NEW_RULES[@]}"
report_category "Modified rules" "${MOD_RULES[@]}"
report_category "Deleted rules" "${DEL_RULES[@]}"
report_category "New hooks" "${NEW_HOOKS[@]}"
report_category "Modified hooks" "${MOD_HOOKS[@]}"
report_category "New commands" "${NEW_COMMANDS[@]}"
report_category "Modified commands" "${MOD_COMMANDS[@]}"
report_category "New skills" "${NEW_SKILLS[@]}"
report_category "Modified skills" "${MOD_SKILLS[@]}"
report_category "Agent changes (manual review only)" "${NEW_AGENTS[@]}" "${MOD_AGENTS[@]}" "${DEL_AGENTS[@]}"

if (( ${#NEW_AGENTS[@]} + ${#MOD_AGENTS[@]} + ${#DEL_AGENTS[@]} > 0 )); then
  log "WARNING: Agent changes detected. Manual review required; no auto-apply performed."
fi

[[ "$REPORT_ONLY" == true ]] && exit 0
[[ "$DRY_RUN" == true ]] && { log "DRY-RUN complete."; exit 0; }

cp "$CURRENT_SNAPSHOT" "$BASELINE_FILE"
APPLIED_FILES+=(".claude-snapshot-baseline.json")
cd "$MYCONVERGIO_HOME"
if git diff --quiet -- "${APPLIED_FILES[@]}"; then
  log "No file changes to commit."
  exit 0
fi

close_stale_prs
BRANCH="sync/claude-alignment-$(date +%Y%m%d)"
git fetch origin master --quiet || true
git checkout -B "$BRANCH" --quiet
git add "${APPLIED_FILES[@]}"
git commit -m "chore(sync): align .claude global ($(date +%F))" -m \
"Rules: +${#NEW_RULES[@]} ~${#MOD_RULES[@]} -${#DEL_RULES[@]}
Hooks: +${#NEW_HOOKS[@]} ~${#MOD_HOOKS[@]} -${#DEL_HOOKS[@]}
Commands: +${#NEW_COMMANDS[@]} ~${#MOD_COMMANDS[@]} -${#DEL_COMMANDS[@]}
Skills: +${#NEW_SKILLS[@]} ~${#MOD_SKILLS[@]} -${#DEL_SKILLS[@]}" >/dev/null
git push -u origin "$BRANCH" >/dev/null

{
  printf '## Summary\n'
  printf -- '- Rules: +%s ~%s -%s\n' "${#NEW_RULES[@]}" "${#MOD_RULES[@]}" "${#DEL_RULES[@]}"
  printf -- '- Hooks: +%s ~%s -%s\n' "${#NEW_HOOKS[@]}" "${#MOD_HOOKS[@]}" "${#DEL_HOOKS[@]}"
  printf -- '- Commands: +%s ~%s -%s\n' "${#NEW_COMMANDS[@]}" "${#MOD_COMMANDS[@]}" "${#DEL_COMMANDS[@]}"
  printf -- '- Skills: +%s ~%s -%s\n' "${#NEW_SKILLS[@]}" "${#MOD_SKILLS[@]}" "${#DEL_SKILLS[@]}"
  printf -- '- Agents (manual): +%s ~%s -%s\n' "${#NEW_AGENTS[@]}" "${#MOD_AGENTS[@]}" "${#DEL_AGENTS[@]}"
} > "$PR_BODY_FILE"

gh pr create --repo Roberdan/MyConvergio --base master --head "$BRANCH" \
  --title "sync: align with .claude global ($(date +%F))" \
  --body-file "$PR_BODY_FILE" >/dev/null

log "PR created for branch $BRANCH"
