mod cli;
mod crdt;
mod models;
mod queries;
mod service;

pub use models::{
    ActivePlan, ExecutionTaskNode, ExecutionTree, ExecutionWaveNode, InProgressTask, StatusView,
    TaskStatus, UpdateTaskArgs, UpdateTaskResult, ValidateTaskArgs, ValidateTaskResult,
};
use rusqlite::Connection;
use std::path::{Path, PathBuf};

pub struct PlanDb {
    conn: Connection,
    db_path: Option<PathBuf>,
    crsqlite_extension: Option<String>,
}

impl PlanDb {
    pub fn open_in_memory() -> rusqlite::Result<Self> {
        Ok(Self {
            conn: Connection::open_in_memory()?,
            db_path: None,
            crsqlite_extension: None,
        })
    }

    pub fn open_path(path: &Path, crsqlite_extension: Option<String>) -> rusqlite::Result<Self> {
        let conn = Connection::open(path)?;
        let extension = crsqlite_extension.unwrap_or_else(|| "crsqlite".to_string());
        crdt::load_crsqlite(&conn, &extension)?;
        crdt::mark_required_tables(&conn)?;
        Ok(Self {
            conn,
            db_path: Some(path.to_path_buf()),
            crsqlite_extension: Some(extension),
        })
    }

    pub fn open_sqlite_path(path: &Path) -> rusqlite::Result<Self> {
        let conn = Connection::open(path)?;
        Ok(Self {
            conn,
            db_path: Some(path.to_path_buf()),
            crsqlite_extension: None,
        })
    }

    pub fn connection(&self) -> &Connection {
        &self.conn
    }
}

#[cfg(test)]
mod tests;
