#!/usr/bin/env bash
# add-knowledge-base.sh — Add knowledge_base table + earned_skills VIEW
set -euo pipefail

DB="${DASHBOARD_DB:-$HOME/.claude/data/dashboard.db}"

sqlite3 "$DB" <<'SQL'
-- Knowledge Base table (vector-ready schema)
CREATE TABLE IF NOT EXISTS knowledge_base (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL CHECK(domain IN ('pattern','decision','convention','learning','error')),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT,  -- JSON array
    confidence REAL DEFAULT 0.5 CHECK(confidence >= 0.0 AND confidence <= 1.0),
    source_type TEXT NOT NULL CHECK(source_type IN ('plan','task','manual','observed')),
    source_ref TEXT,
    project_id TEXT,
    embedding BLOB,  -- nullable: future vector migration
    hit_count INTEGER DEFAULT 0,
    last_hit_at DATETIME,
    promoted INTEGER DEFAULT 0,
    skill_name TEXT,  -- set when promoted=1
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Auto-update updated_at trigger
CREATE TRIGGER IF NOT EXISTS knowledge_base_updated_at
AFTER UPDATE ON knowledge_base
FOR EACH ROW
BEGIN
    UPDATE knowledge_base SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

-- Earned Skills as VIEW (not separate table)
DROP VIEW IF EXISTS earned_skills;
CREATE VIEW earned_skills AS
SELECT id, skill_name, domain, content, confidence, source_type, source_ref,
       tags, hit_count, promoted, created_at, updated_at
FROM knowledge_base
WHERE promoted = 1;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_kb_domain ON knowledge_base(domain);
CREATE INDEX IF NOT EXISTS idx_kb_project ON knowledge_base(project_id);
CREATE INDEX IF NOT EXISTS idx_kb_confidence ON knowledge_base(confidence DESC);
CREATE INDEX IF NOT EXISTS idx_kb_promoted ON knowledge_base(promoted) WHERE promoted = 1;
SQL

echo "[OK] Knowledge base migration complete"
