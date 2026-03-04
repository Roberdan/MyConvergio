#!/usr/bin/env bash
# plan-db-knowledge.sh — Knowledge Base + Earned Skills module
# Sourced by plan-db.sh. Do NOT execute directly.

# Source guard
[[ -n "${_PLAN_DB_KNOWLEDGE_LOADED:-}" ]] && return 0
_PLAN_DB_KNOWLEDGE_LOADED=1

DB="${DASHBOARD_DB:-$HOME/.claude/data/dashboard.db}"

kb_write() {
    local domain="$1" title="$2" content="$3"
    shift 3
    local tags="" confidence="0.5" source_type="manual" source_ref="" project_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tags) tags="$2"; shift 2;;
            --confidence) confidence="$2"; shift 2;;
            --source-type) source_type="$2"; shift 2;;
            --source-ref) source_ref="$2"; shift 2;;
            --project-id) project_id="$2"; shift 2;;
            *) shift;;
        esac
    done
    local id
    id=$(sqlite3 "$DB" "INSERT INTO knowledge_base (domain, title, content, tags, confidence, source_type, source_ref, project_id) VALUES ('$domain', '$(echo "$title" | sed "s/'/''/g")', '$(echo "$content" | sed "s/'/''/g")', '$(echo "$tags" | sed "s/'/''/g")', $confidence, '$source_type', '$source_ref', '$project_id'); SELECT last_insert_rowid();")
    echo "{\"id\":$id,\"domain\":\"$domain\",\"title\":\"$title\"}"
}

kb_search() {
    local query="$1"
    shift
    local domain="" limit="10"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2;;
            --limit) limit="$2"; shift 2;;
            *) shift;;
        esac
    done
    local where="1=1"
    if [[ -n "$query" ]]; then
        local escaped_q
        escaped_q=$(echo "$query" | sed "s/'/''/g")
        where="(title LIKE '%${escaped_q}%' OR content LIKE '%${escaped_q}%')"
    fi
    if [[ -n "$domain" ]]; then
        where="$where AND domain='$domain'"
    fi
    sqlite3 -json "$DB" "SELECT id, domain, title, substr(content,1,200) as content, confidence, hit_count, source_type, source_ref, promoted, skill_name FROM knowledge_base WHERE $where ORDER BY confidence DESC, hit_count DESC LIMIT $limit;" 2>/dev/null || echo "[]"
}

kb_hit() {
    local id="$1"
    sqlite3 "$DB" "UPDATE knowledge_base SET hit_count = hit_count + 1, last_hit_at = CURRENT_TIMESTAMP WHERE id = $id;"
    echo "{\"id\":$id,\"status\":\"hit_recorded\"}"
}

skill_earn() {
    local name="$1" domain="$2" content="$3"
    shift 3
    local confidence="low" source="earned" source_refs=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --confidence) confidence="$2"; shift 2;;
            --source) source="$2"; shift 2;;
            --source-refs) source_refs="$2"; shift 2;;
            *) shift;;
        esac
    done
    # Map text confidence to real
    local conf_real
    case "$confidence" in
        low) conf_real="0.3";;
        medium) conf_real="0.6";;
        high) conf_real="0.9";;
        *) conf_real="0.3";;
    esac
    local escaped_name escaped_content escaped_refs
    escaped_name=$(echo "$name" | sed "s/'/''/g")
    escaped_content=$(echo "$content" | sed "s/'/''/g")
    escaped_refs=$(echo "$source_refs" | sed "s/'/''/g")
    # Check if exists
    local existing
    existing=$(sqlite3 "$DB" "SELECT id FROM knowledge_base WHERE skill_name='$escaped_name' LIMIT 1;" 2>/dev/null)
    if [[ -n "$existing" ]]; then
        echo "{\"error\":\"skill '$name' already exists (id=$existing). Use skill-bump to increase confidence.\"}"
        return 1
    fi
    local id
    id=$(sqlite3 "$DB" "INSERT INTO knowledge_base (domain, title, content, tags, confidence, source_type, source_ref, skill_name, promoted) VALUES ('$domain', '$escaped_name', '$escaped_content', '$escaped_refs', $conf_real, '$source', '', '$escaped_name', 0); SELECT last_insert_rowid();")
    echo "{\"id\":$id,\"skill_name\":\"$name\",\"confidence\":\"$confidence\",\"promoted\":false}"
}

skill_list() {
    local domain="" min_confidence=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) domain="$2"; shift 2;;
            --min-confidence) min_confidence="$2"; shift 2;;
            *) shift;;
        esac
    done
    local where="skill_name IS NOT NULL"
    if [[ -n "$domain" ]]; then
        where="$where AND domain='$domain'"
    fi
    if [[ -n "$min_confidence" ]]; then
        local min_real
        case "$min_confidence" in
            low) min_real="0.3";;
            medium) min_real="0.6";;
            high) min_real="0.9";;
            *) min_real="0.0";;
        esac
        where="$where AND confidence >= $min_real"
    fi
    sqlite3 -json "$DB" "SELECT id, skill_name, domain, substr(content,1,200) as content, confidence, promoted, hit_count FROM knowledge_base WHERE $where ORDER BY confidence DESC;" 2>/dev/null || echo "[]"
}

skill_promote() {
    local name="$1"
    local escaped_name
    escaped_name=$(echo "$name" | sed "s/'/''/g")
    local row
    row=$(sqlite3 -json "$DB" "SELECT id, domain, content, confidence FROM knowledge_base WHERE skill_name='$escaped_name' LIMIT 1;" 2>/dev/null)
    if [[ "$row" == "[]" || -z "$row" ]]; then
        echo "{\"error\":\"skill '$name' not found\"}"
        return 1
    fi
    local domain content
    domain=$(echo "$row" | jq -r '.[0].domain')
    content=$(echo "$row" | jq -r '.[0].content')
    # Generate SKILL.md
    local skill_dir="$HOME/.claude/skills/$domain"
    mkdir -p "$skill_dir"
    cat > "$skill_dir/SKILL.md" <<SKILLEOF
---
name: $name
description: "Earned skill: $name"
domain: "$domain"
confidence: "high"
source: "earned"
version: "1.0.0"
---

# $name

$content
SKILLEOF
    # Update DB
    sqlite3 "$DB" "UPDATE knowledge_base SET promoted = 1 WHERE skill_name = '$escaped_name';"
    echo "{\"skill_name\":\"$name\",\"promoted\":true,\"path\":\"skills/$domain/SKILL.md\"}"
}

skill_bump() {
    local name="$1"
    local escaped_name
    escaped_name=$(echo "$name" | sed "s/'/''/g")
    local current
    current=$(sqlite3 "$DB" "SELECT confidence FROM knowledge_base WHERE skill_name='$escaped_name' LIMIT 1;" 2>/dev/null)
    if [[ -z "$current" ]]; then
        echo "{\"error\":\"skill '$name' not found\"}"
        return 1
    fi
    local new_conf
    if (( $(echo "$current < 0.5" | bc -l) )); then
        new_conf="0.6"
    elif (( $(echo "$current < 0.8" | bc -l) )); then
        new_conf="0.9"
    else
        new_conf="$current"
    fi
    sqlite3 "$DB" "UPDATE knowledge_base SET confidence = $new_conf WHERE skill_name = '$escaped_name';"
    echo "{\"skill_name\":\"$name\",\"previous_confidence\":$current,\"new_confidence\":$new_conf}"
}
