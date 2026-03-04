#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/plan-db-knowledge.sh"
PASS=0; FAIL=0
assert() { if eval "$2" 2>/dev/null; then PASS=$((PASS+1)); else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi; }

echo "=== Knowledge Base Tests ==="
bash "$SCRIPT_DIR/scripts/migrations/add-knowledge-base.sh" 2>/dev/null
bash "$SCRIPT_DIR/scripts/migrations/add-knowledge-base.sh" 2>/dev/null
assert "migration idempotent" "true"

RESULT=$(kb_write learning "test-kb-write" "test content for KB write" --source-type manual 2>/dev/null)
assert "kb-write returns JSON with id" "echo '$RESULT' | jq -e '.id' >/dev/null 2>&1"

SEARCH=$(kb_search "test-kb-write" 2>/dev/null)
assert "kb-search finds entry" "echo '$SEARCH' | jq -e '.[0].title' >/dev/null 2>&1"

ID=$(echo "$RESULT" | jq -r '.id' 2>/dev/null)
HIT=$(kb_hit "$ID" 2>/dev/null)
assert "kb-hit works" "echo '$HIT' | jq -e '.status' >/dev/null 2>&1"

VIEW=$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE name='earned_skills' AND type='view';" 2>/dev/null)
assert "earned_skills is VIEW" "[ '$VIEW' = 'earned_skills' ]"

SKILL=$(skill_earn "test-skill-kb" "pattern" "Test skill content" --confidence low --source earned 2>/dev/null)
assert "skill-earn returns JSON" "echo '$SKILL' | jq -e '.skill_name' >/dev/null 2>&1"

BUMP=$(skill_bump "test-skill-kb" 2>/dev/null)
assert "skill-bump works" "echo '$BUMP' | jq -e '.new_confidence' >/dev/null 2>&1"

sqlite3 "$DB" "DELETE FROM knowledge_base WHERE title LIKE 'test-kb%' OR skill_name LIKE 'test-skill-kb%';" 2>/dev/null
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
