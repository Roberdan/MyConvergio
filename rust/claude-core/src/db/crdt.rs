use super::PlanDb;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::io::{Error as IoError, ErrorKind, Write};
use std::process::{Command, Stdio};

const REQUIRED_CRDT_TABLES: [&str; 4] = ["plan_reviews", "tasks", "waves", "host_heartbeats"];

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
    let _guard = unsafe { conn.load_extension_enable()? };
    unsafe { conn.load_extension(extension, None::<&str>) }?;
    Ok(())
}

pub fn mark_required_tables(conn: &Connection) -> rusqlite::Result<()> {
    for table in required_crdt_tables() {
        let sql = format!("SELECT crsql_as_crr('{table}')");
        conn.query_row(&sql, [], |_| Ok(()))?;
    }
    Ok(())
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
            return Err(IoError::new(
                ErrorKind::Other,
                format!("remote export failed: {}", String::from_utf8_lossy(&output.stderr)),
            ));
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
            Err(IoError::new(ErrorKind::Other, "remote apply failed"))
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
