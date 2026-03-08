use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use std::path::Path;
use std::sync::{Arc, Mutex};

pub type SharedLock<T> = Arc<Mutex<T>>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LockKind {
    Plan,
    Session,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LockInfo {
    pub file_path: String,
    pub lock_kind: LockKind,
    pub plan_id: Option<i64>,
    pub task_id: Option<String>,
    pub session_id: Option<String>,
    pub owner_name: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AcquireOutcome {
    Acquired,
    Reentrant,
    Blocked(LockInfo),
}

pub struct FileLockStore {
    conn: Connection,
}

enum LockClaim<'a> {
    Plan {
        task_id: &'a str,
        plan_id: Option<i64>,
        owner_name: &'a str,
    },
    Session {
        session_id: &'a str,
        owner_name: &'a str,
    },
}

impl<'a> LockClaim<'a> {
    fn lock_kind(&self) -> &'static str {
        match self {
            Self::Plan { .. } => "plan",
            Self::Session { .. } => "session",
        }
    }
}

impl FileLockStore {
    pub fn open(path: impl AsRef<Path>) -> rusqlite::Result<Self> {
        let conn = Connection::open(path)?;
        let store = Self { conn };
        store.init_schema()?;
        Ok(store)
    }

    pub fn open_in_memory() -> rusqlite::Result<Self> {
        let conn = Connection::open_in_memory()?;
        let store = Self { conn };
        store.init_schema()?;
        Ok(store)
    }

    pub fn acquire_plan(
        &mut self,
        file_path: &str,
        task_id: &str,
        plan_id: Option<i64>,
        owner_name: &str,
    ) -> rusqlite::Result<AcquireOutcome> {
        self.acquire_lock(
            file_path,
            LockClaim::Plan {
                task_id,
                plan_id,
                owner_name,
            },
        )
    }

    pub fn acquire_session(
        &mut self,
        file_path: &str,
        session_id: &str,
        owner_name: &str,
    ) -> rusqlite::Result<AcquireOutcome> {
        self.acquire_lock(
            file_path,
            LockClaim::Session {
                session_id,
                owner_name,
            },
        )
    }

    pub fn release_file(&self, file_path: &str) -> rusqlite::Result<usize> {
        self.conn
            .execute("DELETE FROM file_locks WHERE file_path = ?1", params![file_path])
    }

    pub fn release_task(&self, task_id: &str) -> rusqlite::Result<usize> {
        self.conn
            .execute("DELETE FROM file_locks WHERE task_id = ?1", params![task_id])
    }

    pub fn release_session(&self, session_id: &str) -> rusqlite::Result<usize> {
        self.conn.execute(
            "DELETE FROM file_locks WHERE session_id = ?1",
            params![session_id],
        )
    }

    pub fn get_lock(&self, file_path: &str) -> rusqlite::Result<Option<LockInfo>> {
        self.conn
            .query_row(
                "SELECT file_path, lock_kind, plan_id, task_id, session_id, owner_name
                 FROM file_locks WHERE file_path = ?1",
                params![file_path],
                map_lock_row,
            )
            .optional()
    }

    fn init_schema(&self) -> rusqlite::Result<()> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS file_locks (
                file_path TEXT PRIMARY KEY,
                lock_kind TEXT NOT NULL CHECK(lock_kind IN ('plan','session')),
                plan_id INTEGER,
                task_id TEXT,
                session_id TEXT,
                owner_name TEXT NOT NULL,
                acquired_at TEXT NOT NULL DEFAULT (datetime('now')),
                heartbeat_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_file_locks_task_id ON file_locks(task_id);
            CREATE INDEX IF NOT EXISTS idx_file_locks_session_id ON file_locks(session_id);",
        )
    }

    fn acquire_lock(&mut self, file_path: &str, claim: LockClaim<'_>) -> rusqlite::Result<AcquireOutcome> {
        let tx = self
            .conn
            .transaction_with_behavior(TransactionBehavior::Immediate)?;

        if let Some(existing) = tx
            .query_row(
                "SELECT file_path, lock_kind, plan_id, task_id, session_id, owner_name
                 FROM file_locks WHERE file_path = ?1",
                params![file_path],
                map_lock_row,
            )
            .optional()?
        {
            if is_reentrant(&claim, &existing) {
                let owner_name = match &claim {
                    LockClaim::Plan { owner_name, .. } => owner_name,
                    LockClaim::Session { owner_name, .. } => owner_name,
                };
                tx.execute(
                    "UPDATE file_locks
                     SET owner_name = ?1, heartbeat_at = datetime('now')
                     WHERE file_path = ?2",
                    params![owner_name, file_path],
                )?;
                tx.commit()?;
                return Ok(AcquireOutcome::Reentrant);
            }
            tx.commit()?;
            return Ok(AcquireOutcome::Blocked(existing));
        }

        let (plan_id, task_id, session_id, owner_name) = match claim {
            LockClaim::Plan {
                task_id,
                plan_id,
                owner_name,
            } => (plan_id, Some(task_id), None, owner_name),
            LockClaim::Session {
                session_id,
                owner_name,
            } => (None, None, Some(session_id), owner_name),
        };

        tx.execute(
            "INSERT INTO file_locks(file_path, lock_kind, plan_id, task_id, session_id, owner_name)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                file_path,
                claim.lock_kind(),
                plan_id,
                task_id,
                session_id,
                owner_name
            ],
        )?;
        tx.commit()?;
        Ok(AcquireOutcome::Acquired)
    }
}

fn is_reentrant(claim: &LockClaim<'_>, existing: &LockInfo) -> bool {
    match (claim, &existing.lock_kind) {
        (LockClaim::Plan { task_id, .. }, LockKind::Plan) => {
            existing.task_id.as_deref() == Some(*task_id)
        }
        (LockClaim::Session { session_id, .. }, LockKind::Session) => {
            existing.session_id.as_deref() == Some(*session_id)
        }
        _ => false,
    }
}

fn map_lock_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<LockInfo> {
    let lock_kind = match row.get::<_, String>(1)?.as_str() {
        "plan" => LockKind::Plan,
        _ => LockKind::Session,
    };
    Ok(LockInfo {
        file_path: row.get(0)?,
        lock_kind,
        plan_id: row.get(2)?,
        task_id: row.get(3)?,
        session_id: row.get(4)?,
        owner_name: row.get(5)?,
    })
}

#[cfg(test)]
mod tests;
