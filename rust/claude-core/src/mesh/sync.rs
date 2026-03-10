use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::io::ErrorKind;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
#[cfg(test)]
#[path = "sync_tests.rs"]
mod sync_tests;
#[path = "sync_batch.rs"]
mod sync_batch;
pub use sync_batch::{current_time_ms, SyncBatchWindow};
const MAX_FRAME_BYTES: u32 = 16 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeltaChange {
    pub table_name: String,
    #[serde(with = "base64_bytes")]
    pub pk: Vec<u8>,
    pub cid: String,
    pub val: Option<String>,
    pub col_version: i64,
    pub db_version: i64,
    #[serde(with = "base64_bytes")]
    pub site_id: Vec<u8>,
    pub cl: i64,
    pub seq: i64,
}

mod base64_bytes {
    use serde::{Deserialize, Deserializer, Serializer};
    use base64::Engine;
    pub fn serialize<S: Serializer>(bytes: &Vec<u8>, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&base64::engine::general_purpose::STANDARD.encode(bytes))
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<u8>, D::Error> {
        let s = String::deserialize(d)?;
        base64::engine::general_purpose::STANDARD.decode(&s).map_err(serde::de::Error::custom)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MeshSyncFrame {
    Heartbeat { node: String, ts: u64 },
    Delta {
        node: String,
        sent_at_ms: u64,
        last_db_version: i64,
        changes: Vec<DeltaChange>,
    },
    Ack {
        node: String,
        applied: usize,
        latency_ms: u64,
        last_db_version: i64,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ApplySummary {
    pub applied: usize,
    pub latency_ms: u64,
    pub last_db_version: i64,
}

pub async fn write_frame<W: AsyncWrite + Unpin>(writer: &mut W, frame: &MeshSyncFrame) -> Result<(), String> {
    let payload = rmp_serde::to_vec_named(frame).map_err(|e| e.to_string())?;
    let len = u32::try_from(payload.len()).map_err(|_| "mesh frame too large".to_string())?;
    writer
        .write_all(&len.to_be_bytes())
        .await
        .map_err(|e| e.to_string())?;
    writer.write_all(&payload).await.map_err(|e| e.to_string())
}

pub async fn read_frame<R: AsyncRead + Unpin>(reader: &mut R) -> Result<Option<MeshSyncFrame>, String> {
    let mut len_buf = [0_u8; 4];
    match reader.read_exact(&mut len_buf).await {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::UnexpectedEof => return Ok(None),
        Err(err) => return Err(err.to_string()),
    }
    let payload_len = u32::from_be_bytes(len_buf);
    if payload_len > MAX_FRAME_BYTES {
        return Err(format!("mesh frame exceeds limit: {payload_len}"));
    }
    let mut payload = vec![0_u8; payload_len as usize];
    reader
        .read_exact(&mut payload)
        .await
        .map_err(|e| e.to_string())?;
    let frame = rmp_serde::from_slice::<MeshSyncFrame>(&payload).map_err(|e| e.to_string())?;
    Ok(Some(frame))
}

pub fn collect_changes_since(
    db_path: &Path,
    crsqlite_ext: Option<&str>,
    last_db_version: i64,
) -> Result<(Vec<DeltaChange>, i64), String> {
    let conn = open_sync_conn(db_path, crsqlite_ext)?;
    ensure_sync_schema(&conn).map_err(|e| e.to_string())?;
    let changes = read_local_changes_since(&conn, last_db_version).map_err(|e| e.to_string())?;
    let max_db_version = changes.iter().map(|c| c.db_version).max().unwrap_or(last_db_version);
    Ok((changes, max_db_version))
}

/// Get the current max db_version — used to initialize cursor on startup
pub fn current_db_version(db_path: &Path, crsqlite_ext: Option<&str>) -> Result<i64, String> {
    let conn = open_sync_conn(db_path, crsqlite_ext)?;
    conn.query_row(
        "SELECT COALESCE(MAX(db_version), 0) FROM crsql_changes",
        [],
        |r| r.get(0),
    )
    .map_err(|e| e.to_string())
}

pub fn apply_delta_frame(
    db_path: &Path,
    crsqlite_ext: Option<&str>,
    peer_name: &str,
    sent_at_ms: u64,
    changes: &[DeltaChange],
) -> Result<ApplySummary, String> {
    let conn = open_sync_conn(db_path, crsqlite_ext)?;
    ensure_sync_schema(&conn).map_err(|e| e.to_string())?;
    let applied = apply_changes_to_conn(&conn, changes).map_err(|e| e.to_string())?;
    let latency = now_ms().saturating_sub(sent_at_ms);
    let last_db_version = changes.iter().map(|c| c.db_version).max().unwrap_or(0);
    conn.execute(
        "INSERT INTO mesh_sync_stats(peer_name,total_received,total_applied,last_sync_at,last_latency_ms,last_db_version,last_error)
         VALUES(?1, ?2, ?3, strftime('%s','now'), ?4, ?5, NULL)
         ON CONFLICT(peer_name) DO UPDATE SET
           total_received = total_received + excluded.total_received,
           total_applied = total_applied + excluded.total_applied,
           last_sync_at = excluded.last_sync_at,
           last_latency_ms = excluded.last_latency_ms,
           last_db_version = MAX(mesh_sync_stats.last_db_version, excluded.last_db_version),
           last_error = NULL",
        params![peer_name, changes.len() as i64, applied as i64, latency as i64, last_db_version],
    )
    .map_err(|e| e.to_string())?;
    Ok(ApplySummary {
        applied,
        latency_ms: latency,
        last_db_version,
    })
}

pub fn record_sent_stats(
    db_path: &Path,
    crsqlite_ext: Option<&str>,
    peer_name: &str,
    sent_count: usize,
    last_db_version: i64,
) -> Result<(), String> {
    let conn = open_sync_conn(db_path, crsqlite_ext)?;
    ensure_sync_schema(&conn).map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO mesh_sync_stats(peer_name,total_sent,last_sent_at,last_db_version,last_error)
         VALUES(?1, ?2, strftime('%s','now'), ?3, NULL)
         ON CONFLICT(peer_name) DO UPDATE SET
           total_sent = total_sent + excluded.total_sent,
           last_sent_at = excluded.last_sent_at,
           last_db_version = MAX(mesh_sync_stats.last_db_version, excluded.last_db_version),
           last_error = NULL",
        params![peer_name, sent_count as i64, last_db_version],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn record_sync_error(
    db_path: &Path,
    crsqlite_ext: Option<&str>,
    peer_name: &str,
    error: &str,
) -> Result<(), String> {
    let conn = open_sync_conn(db_path, crsqlite_ext)?;
    ensure_sync_schema(&conn).map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO mesh_sync_stats(peer_name,last_error,last_sync_at)
         VALUES(?1, ?2, strftime('%s','now'))
         ON CONFLICT(peer_name) DO UPDATE SET
           last_error = excluded.last_error,
           last_sync_at = excluded.last_sync_at",
        params![peer_name, error],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}

/// Read only LOCAL changes (filtered by this node's site_id) — prevents re-broadcast loops
fn read_local_changes_since(conn: &Connection, last_db_version: i64) -> rusqlite::Result<Vec<DeltaChange>> {
    // Get local site_id to filter — only send OUR writes, not re-broadcast received changes
    let local_site_id: Option<Vec<u8>> = conn
        .query_row("SELECT site_id FROM crsql_site_id LIMIT 1", [], |r| r.get(0))
        .ok();
    let mut stmt = conn.prepare(
        r#"SELECT "table", pk, cid, CAST(val AS TEXT), col_version, db_version, site_id, cl, seq
           FROM crsql_changes
           WHERE db_version > ?1 AND (?2 IS NULL OR site_id = ?2)
           ORDER BY db_version ASC, seq ASC
           LIMIT 1000"#,
    )?;
    let rows = stmt.query_map(params![last_db_version, local_site_id], |row| {
        Ok(DeltaChange {
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

pub fn read_changes_since_from_conn(conn: &Connection, last_db_version: i64) -> rusqlite::Result<Vec<DeltaChange>> {
    let mut stmt = conn.prepare(
        r#"SELECT "table", pk, cid, CAST(val AS TEXT), col_version, db_version, site_id, cl, seq
           FROM crsql_changes
           WHERE db_version > ?1
           ORDER BY db_version ASC, seq ASC"#,
    )?;
    let rows = stmt.query_map([last_db_version], |row| {
        Ok(DeltaChange {
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

fn apply_changes_to_conn(conn: &Connection, changes: &[DeltaChange]) -> rusqlite::Result<usize> {
    if changes.is_empty() {
        return Ok(0);
    }
    conn.execute_batch("BEGIN")?;
    let mut applied = 0;
    let result = (|| -> rusqlite::Result<usize> {
        let mut stmt = conn.prepare_cached(
            r#"INSERT INTO crsql_changes ("table", pk, cid, val, col_version, db_version, site_id, cl, seq)
               VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)"#,
        )?;
        for change in changes {
            stmt.execute(params![
                change.table_name,
                change.pk,
                change.cid,
                change.val,
                change.col_version,
                change.db_version,
                change.site_id,
                change.cl,
                change.seq
            ])?;
            applied += 1;
        }
        Ok(applied)
    })();
    match result {
        Ok(count) => { conn.execute_batch("COMMIT")?; Ok(count) }
        Err(e) => { let _ = conn.execute_batch("ROLLBACK"); Err(e) }
    }
}

/// Open a long-lived sync connection (call once, reuse across ticks)
pub fn open_persistent_sync_conn(db_path: &Path, crsqlite_ext: Option<&str>) -> Result<Connection, String> {
    open_sync_conn(db_path, crsqlite_ext)
}

/// Collect local changes using an existing connection (avoids opening new one per tick)
pub fn collect_changes_with_conn(conn: &Connection, last_db_version: i64) -> Result<(Vec<DeltaChange>, i64), String> {
    let changes = read_local_changes_since(conn, last_db_version).map_err(|e| e.to_string())?;
    let max_db_version = changes.iter().map(|c| c.db_version).max().unwrap_or(last_db_version);
    Ok((changes, max_db_version))
}

/// Record sent stats using an existing connection
pub fn record_sent_stats_with_conn(conn: &Connection, peer_name: &str, sent_count: usize, last_db_version: i64) -> Result<(), String> {
    ensure_sync_schema(conn).map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT INTO mesh_sync_stats(peer_name,total_sent,last_sent_at,last_db_version,last_error)
         VALUES(?1, ?2, strftime('%s','now'), ?3, NULL)
         ON CONFLICT(peer_name) DO UPDATE SET
           total_sent = total_sent + excluded.total_sent,
           last_sent_at = excluded.last_sent_at,
           last_db_version = MAX(mesh_sync_stats.last_db_version, excluded.last_db_version),
           last_error = NULL",
        params![peer_name, sent_count as i64, last_db_version],
    )
    .map_err(|e| e.to_string())?;
    Ok(())
}
pub fn current_db_version_with_conn(conn: &Connection) -> Result<i64, String> {
    conn.query_row(
        "SELECT COALESCE(MAX(db_version), 0) FROM crsql_changes",
        [],
        |r| r.get(0),
    )
    .map_err(|e| e.to_string())
}

fn open_sync_conn(db_path: &Path, crsqlite_ext: Option<&str>) -> Result<Connection, String> {
    let conn = Connection::open(db_path).map_err(|e| e.to_string())?;
    conn.execute_batch(
        "PRAGMA journal_mode=WAL;
         PRAGMA synchronous=NORMAL;
         PRAGMA busy_timeout=5000;
         PRAGMA cache_size=-2000;"
    ).map_err(|e| e.to_string())?;
    if let Some(ext) = crsqlite_ext {
        let _guard = unsafe { conn.load_extension_enable() }.map_err(|e| e.to_string())?;
        unsafe { conn.load_extension(ext, None::<&str>) }.map_err(|e| e.to_string())?;
        // Ensure ALL tables are CRR-enabled for automatic row-level replication
        crate::db::crdt::mark_required_tables(&conn).map_err(|e| e.to_string())?;
    }
    Ok(conn)
}

pub fn ensure_sync_schema_pub(conn: &Connection) -> rusqlite::Result<()> {
    ensure_sync_schema(conn)
}

fn ensure_sync_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS mesh_sync_stats (
            peer_name TEXT PRIMARY KEY,
            total_sent INTEGER NOT NULL DEFAULT 0,
            total_received INTEGER NOT NULL DEFAULT 0,
            total_applied INTEGER NOT NULL DEFAULT 0,
            last_sent_at INTEGER,
            last_sync_at INTEGER,
            last_latency_ms INTEGER,
            last_db_version INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
        );",
    )
}

fn now_ms() -> u64 { SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as u64).unwrap_or(0) }
