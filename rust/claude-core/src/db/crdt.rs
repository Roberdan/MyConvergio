use super::PlanDb;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::io::{Error as IoError, ErrorKind, Write};
use std::process::{Command, Stdio};

// ALL operational tables CRR-enabled for automatic row-level replication.
// Excluded: plan_versions_backup (no PK — it's a raw dump backup table)
const REQUIRED_CRDT_TABLES: [&str; 42] = [
    "agent_activity",
    "agent_runs",
    "chat_messages",
    "chat_requirements",
    "chat_sessions",
    "collector_runs",
    "conversation_logs",
    "debt_items",
    "delegation_log",
    "env_vault_log",
    "file_locks",
    "file_snapshots",
    "github_events",
    "host_heartbeats",
    "idea_notes",
    "ideas",
    "knowledge_base",
    "merge_queue",
    "mesh_events",
    "mesh_sync_stats",
    "metrics_history",
    "nightly_job_definitions",
    "nightly_jobs",
    "notification_triggers",
    "notifications",
    "peer_heartbeats",
    "plan_actuals",
    "plan_approvals",
    "plan_business_assessments",
    "plan_commits",
    "plan_learnings",
    "plan_reviews",
    "plan_token_estimates",
    "plan_versions",
    "plans",
    "projects",
    "schema_metadata",
    "session_state",
    "snapshots",
    "tasks",
    "token_usage",
    "waves",
];

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CrdtChange {
    pub table_name: String,
    pub pk: String,
    pub cid: String,
    pub val: Option<String>,
    pub col_version: i64,
    pub db_version: i64,
    pub site_id: String,
    pub cl: i64,
    pub seq: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SyncSummary {
    pub peer: String,
    pub sent: usize,
    pub received: usize,
    pub applied: usize,
}

pub fn required_crdt_tables() -> Vec<&'static str> {
    REQUIRED_CRDT_TABLES.to_vec()
}

pub fn load_crsqlite(conn: &Connection, extension: &str) -> rusqlite::Result<()> {
    unsafe { conn.load_extension_enable()? };
    unsafe { conn.load_extension(extension, None::<&str>) }?;
    Ok(())
}

pub fn mark_required_tables(conn: &Connection) -> rusqlite::Result<()> {
    // Clean up any leftover temp tables from failed migrations
    let temps: Vec<String> = {
        let mut stmt = conn.prepare(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '_crr_rebuild_%'"
        )?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;
        let v: Vec<String> = rows.filter_map(|r| r.ok()).collect();
        v
    };
    for tmp in &temps {
        let _ = conn.execute_batch(&format!("DROP TABLE IF EXISTS \"{tmp}\""));
    }
    // Check if any tables need migration
    let needs_migration: bool = required_crdt_tables().iter().any(|table| {
        let clock = format!("{table}__crsql_clock");
        let already: bool = conn.query_row(
            "SELECT count(*) > 0 FROM sqlite_master WHERE type='table' AND name=?1",
            [&clock], |r| r.get(0),
        ).unwrap_or(false);
        !already
    });
    if !needs_migration { return Ok(()); }
    // Save and drop ALL views and user triggers before rebuilding tables.
    // Views/triggers reference tables and crsqlite validates schema — 
    // temporarily dropped tables cause errors during rebuild.
    let views: Vec<(String, String)> = {
        let mut stmt = conn.prepare(
            "SELECT name, sql FROM sqlite_master WHERE type='view'"
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let v: Vec<_> = rows.filter_map(|r| r.ok()).collect();
        v
    };
    let triggers: Vec<(String, String)> = {
        let mut stmt = conn.prepare(
            "SELECT name, sql FROM sqlite_master WHERE type='trigger' AND name NOT LIKE '%__crsql_%' AND sql IS NOT NULL"
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let v: Vec<_> = rows.filter_map(|r| r.ok()).collect();
        v
    };
    for (name, _) in &views {
        let _ = conn.execute_batch(&format!("DROP VIEW IF EXISTS \"{name}\""));
    }
    for (name, _) in &triggers {
        let _ = conn.execute_batch(&format!("DROP TRIGGER IF EXISTS \"{name}\""));
    }
    for table in required_crdt_tables() {
        let clock_table = format!("{table}__crsql_clock");
        let already: bool = conn.query_row(
            "SELECT count(*) > 0 FROM sqlite_master WHERE type='table' AND name=?1",
            [&clock_table], |r| r.get(0),
        )?;
        if already { continue; }
        let exists: bool = conn.query_row(
            "SELECT count(*) > 0 FROM sqlite_master WHERE type='table' AND name=?1",
            [table], |r| r.get(0),
        )?;
        if !exists { continue; }
        let crr_sql = format!("SELECT crsql_as_crr('{table}')");
        if conn.query_row(&crr_sql, [], |_| Ok(())).is_ok() {
            continue;
        }
        drop_unique_indices(conn, table)?;
        if conn.query_row(&crr_sql, [], |_| Ok(())).is_ok() {
            continue;
        }
        rebuild_crr_compatible(conn, table)?;
        conn.query_row(&crr_sql, [], |_| Ok(()))?;
    }
    // Restore views and triggers
    for (_, sql) in &views {
        let _ = conn.execute_batch(sql);
    }
    for (_, sql) in &triggers {
        let _ = conn.execute_batch(sql);
    }
    Ok(())
}

fn drop_unique_indices(conn: &Connection, table: &str) -> rusqlite::Result<()> {
    let indices: Vec<String> = {
        let mut stmt = conn.prepare(
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?1 AND sql LIKE '%UNIQUE%'"
        )?;
        let rows = stmt.query_map([table], |row| row.get::<_, String>(0))?;
        let v: Vec<String> = rows.filter_map(|r| r.ok()).collect();
        v
    };
    for idx in &indices {
        conn.execute_batch(&format!("DROP INDEX IF EXISTS \"{idx}\""))?;
    }
    Ok(())
}

/// Rebuild table to be CRR-compatible:
/// 1. Remove UNIQUE constraints
/// 2. Add DEFAULT values to NOT NULL columns (crsqlite requires this)
fn rebuild_crr_compatible(conn: &Connection, table: &str) -> rusqlite::Result<()> {
    // Get column info
    let mut cols: Vec<(String, String, bool, Option<String>, bool)> = Vec::new();
    {
        let mut stmt = conn.prepare(&format!("PRAGMA table_info(\"{}\")", table))?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, bool>(3)?,
                row.get::<_, Option<String>>(4)?,
                row.get::<_, bool>(5)?,
            ))
        })?;
        let v: Vec<_> = rows.collect();
        for row in v {
            cols.push(row?);
        }
    }
    // Get FK info
    let mut fks: Vec<(String, String, String)> = Vec::new();
    {
        let mut stmt = conn.prepare(&format!("PRAGMA foreign_key_list(\"{}\")", table))?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
            ))
        })?;
        let v: Vec<_> = rows.collect();
        for row in v {
            fks.push(row?);
        }
    }
    // Get CHECK constraints from original SQL
    let original_sql: String = conn.query_row(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?1",
        [table],
        |r| r.get(0),
    )?;
    // Build new CREATE TABLE
    let tmp = format!("_crr_rebuild_{table}");
    let mut col_defs: Vec<String> = Vec::new();
    for (name, typ, notnull, dflt, pk) in &cols {
        let mut def = format!("\"{}\" {}", name, typ);
        if *pk {
            def.push_str(" PRIMARY KEY");
            // NOTE: AUTOINCREMENT is intentionally NOT added for CRR tables.
            // crsqlite requires coordinated PKs; AUTOINCREMENT causes ID conflicts
            // between nodes. Bare INTEGER PRIMARY KEY still auto-assigns rowid.
            def.push_str(" NOT NULL");
        }
        if *notnull && !pk {
            def.push_str(" NOT NULL");
            if dflt.is_none() {
                let default = default_for_type(typ);
                def.push_str(&format!(" DEFAULT {default}"));
            }
        }
        if let Some(d) = dflt {
            if !pk {
                // Expression defaults (containing function calls) need parentheses
                if d.contains('(') {
                    def.push_str(&format!(" DEFAULT ({d})"));
                } else {
                    def.push_str(&format!(" DEFAULT {d}"));
                }
            }
        }
        // Extract CHECK constraint for this column from original SQL
        let upper_orig = original_sql.to_uppercase();
        let check_needle = format!("\"{}\"", name.to_uppercase());
        if let Some(pos) = upper_orig.find(&check_needle) {
            let rest = &original_sql[pos..];
            if let Some(check_start) = rest.to_uppercase().find("CHECK(") {
                let check_rest = &rest[check_start..];
                if let Some(end) = find_matching_paren(check_rest, 5) {
                    def.push_str(&format!(" {}", &check_rest[..=end]));
                }
            }
        }
        col_defs.push(def);
    }
    // NOTE: Foreign keys are intentionally NOT added for CRR tables.
    // crsqlite does not allow checked FK constraints in CRR tables because
    // replication can temporarily violate referential integrity.
    let create = format!(
        "CREATE TABLE \"{}\" ({})",
        tmp,
        col_defs.join(", ")
    );
    // Use SAVEPOINT for atomicity — if any step fails, rollback all changes
    match conn.execute_batch(&format!(
        "SAVEPOINT crr_rebuild; {}; INSERT INTO \"{}\" SELECT * FROM \"{}\"; DROP TABLE \"{}\"; ALTER TABLE \"{}\" RENAME TO \"{}\"; RELEASE crr_rebuild;",
        create, tmp, table, table, tmp, table
    )) {
        Ok(()) => {},
        Err(e) => {
            let _ = conn.execute_batch("ROLLBACK TO crr_rebuild; RELEASE crr_rebuild;");
            let _ = conn.execute_batch(&format!("DROP TABLE IF EXISTS \"{}\"", tmp));
            return Err(e);
        }
    };
    Ok(())
}

fn default_for_type(typ: &str) -> &'static str {
    let upper = typ.to_uppercase();
    if upper.contains("INT") { "'0'" }
    else if upper.contains("REAL") || upper.contains("FLOAT") || upper.contains("DOUBLE") { "'0.0'" }
    else if upper.contains("BOOL") { "'0'" }
    else { "''" }  // TEXT, BLOB, JSON, DATETIME, etc.
}

fn find_matching_paren(s: &str, open_pos: usize) -> Option<usize> {
    let bytes = s.as_bytes();
    let mut depth = 0;
    for (i, &b) in bytes.iter().enumerate().skip(open_pos) {
        match b {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 { return Some(i); }
            }
            _ => {}
        }
    }
    None
}

impl PlanDb {
    pub(crate) fn export_changes(&self) -> rusqlite::Result<Vec<CrdtChange>> {
        let mut stmt = self.conn.prepare(
            r#"SELECT "table", pk, cid, CAST(val AS TEXT), col_version, db_version, site_id, cl, seq
               FROM crsql_changes"#,
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(CrdtChange {
                table_name: row.get(0)?,
                pk: row.get(1)?,
                cid: row.get(2)?,
                val: row.get(3)?,
                col_version: row.get(4)?,
                db_version: row.get(5)?,
                site_id: row.get(6)?,
                cl: row.get(7)?,
                seq: row.get(8)?,
            })
        })?;
        rows.collect::<rusqlite::Result<Vec<_>>>()
    }

    pub(crate) fn apply_changes(&self, changes: &[CrdtChange]) -> rusqlite::Result<usize> {
        let mut applied = 0usize;
        for change in changes {
            self.conn.execute(
                r#"INSERT INTO crsql_changes ("table", pk, cid, val, col_version, db_version, site_id, cl, seq)
                   VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)"#,
                params![
                    change.table_name,
                    change.pk,
                    change.cid,
                    change.val,
                    change.col_version,
                    change.db_version,
                    change.site_id,
                    change.cl,
                    change.seq
                ],
            )?;
            applied += 1;
        }
        Ok(applied)
    }

    pub(crate) fn sync_with_peer(&self, peer: &str) -> rusqlite::Result<SyncSummary> {
        let local = self.export_changes()?;
        let remote = self.fetch_remote_changes(peer).map_err(io_as_sql_error)?;
        let applied = self.apply_changes(&remote)?;
        self.send_local_changes(peer, &local)
            .map_err(io_as_sql_error)?;
        Ok(SyncSummary {
            peer: peer.to_string(),
            sent: local.len(),
            received: remote.len(),
            applied,
        })
    }

    fn fetch_remote_changes(&self, peer: &str) -> std::io::Result<Vec<CrdtChange>> {
        let mut cmd = Command::new("ssh");
        cmd.arg(peer).arg("claude-core").arg("db").arg("export-changes");
        if let Some(path) = &self.db_path {
            cmd.arg("--db-path").arg(path);
        }
        if let Some(ext) = &self.crsqlite_extension {
            cmd.arg("--crsqlite-path").arg(ext);
        }
        let output = cmd.output()?;
        if !output.status.success() {
            return Err(IoError::other(format!("remote export failed: {}", String::from_utf8_lossy(&output.stderr))));
        }
        serde_json::from_slice::<Vec<CrdtChange>>(&output.stdout)
            .map_err(|err| IoError::new(ErrorKind::InvalidData, err))
    }

    fn send_local_changes(&self, peer: &str, changes: &[CrdtChange]) -> std::io::Result<()> {
        let payload = serde_json::to_vec(changes)
            .map_err(|err| IoError::new(ErrorKind::InvalidData, err.to_string()))?;
        let mut cmd = Command::new("ssh");
        cmd.arg(peer).arg("claude-core").arg("db").arg("apply-changes");
        if let Some(path) = &self.db_path {
            cmd.arg("--db-path").arg(path);
        }
        if let Some(ext) = &self.crsqlite_extension {
            cmd.arg("--crsqlite-path").arg(ext);
        }
        cmd.stdin(Stdio::piped());
        let mut child = cmd.spawn()?;
        if let Some(stdin) = child.stdin.as_mut() {
            stdin.write_all(&payload)?;
        }
        let status = child.wait()?;
        if status.success() {
            Ok(())
        } else {
            Err(IoError::other("remote apply failed"))
        }
    }
}

fn io_as_sql_error(err: std::io::Error) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(err))
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::functions::FunctionFlags;
    use std::sync::{Arc, Mutex};

    fn seed_change_schema(db: &PlanDb) {
        db.connection()
            .execute_batch(
                r#"
                CREATE TABLE crsql_changes (
                  "table" TEXT NOT NULL,
                  pk TEXT NOT NULL,
                  cid TEXT NOT NULL,
                  val TEXT,
                  col_version INTEGER NOT NULL,
                  db_version INTEGER NOT NULL,
                  site_id TEXT NOT NULL,
                  cl INTEGER NOT NULL,
                  seq INTEGER NOT NULL
                );
                "#,
            )
            .expect("schema");
    }

    #[test]
    fn crdt_marks_required_tables() {
        let conn = Connection::open_in_memory().expect("conn");
        let called = Arc::new(Mutex::new(Vec::<String>::new()));
        let sink = Arc::clone(&called);
        for table in required_crdt_tables() {
            conn.execute(
                &format!("CREATE TABLE \"{table}\" (id TEXT PRIMARY KEY)"),
                [],
            )
            .expect("create table");
        }
        conn.create_scalar_function(
            "crsql_as_crr",
            1,
            FunctionFlags::SQLITE_UTF8,
            move |ctx| {
                sink.lock().expect("lock").push(
                    ctx.get::<String>(0)
                        .expect("table argument for crsql_as_crr"),
                );
                Ok(1_i64)
            },
        )
        .expect("register function");
        mark_required_tables(&conn).expect("mark tables");
        assert_eq!(
            called.lock().expect("lock").clone(),
            required_crdt_tables().into_iter().map(str::to_string).collect::<Vec<_>>()
        );
    }

    #[test]
    fn crdt_changes_converge_between_two_nodes() {
        let left = PlanDb::open_in_memory().expect("left db");
        let right = PlanDb::open_in_memory().expect("right db");
        seed_change_schema(&left);
        seed_change_schema(&right);
        left.connection().execute(
            r#"INSERT INTO crsql_changes ("table",pk,cid,val,col_version,db_version,site_id,cl,seq)
               VALUES ('tasks','id=1','title','left',1,1,'left',1,1)"#,
            [],
        )
        .expect("left change");
        right.connection().execute(
            r#"INSERT INTO crsql_changes ("table",pk,cid,val,col_version,db_version,site_id,cl,seq)
               VALUES ('tasks','id=2','title','right',1,1,'right',1,1)"#,
            [],
        )
        .expect("right change");
        let left_changes = left.export_changes().expect("left export");
        let right_changes = right.export_changes().expect("right export");
        left.apply_changes(&right_changes).expect("left apply");
        right.apply_changes(&left_changes).expect("right apply");
        assert_eq!(left.export_changes().expect("left final").len(), 2);
        assert_eq!(right.export_changes().expect("right final").len(), 2);
    }
}
