use super::{AcquireOutcome, FileLockStore};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

#[test]
fn lock_plan_acquire_blocks_other_plan_task() {
    let db = unique_db_path("plan-block");
    let mut first = FileLockStore::open(&db).expect("first");
    let mut second = FileLockStore::open(&db).expect("second");

    let acquired = first
        .acquire_plan("src/lock/mod.rs", "T10-04", Some(100025), "agent-a")
        .expect("acquire");
    assert_eq!(acquired, AcquireOutcome::Acquired);

    let blocked = second
        .acquire_plan("src/lock/mod.rs", "T10-05", Some(100025), "agent-b")
        .expect("acquire");
    assert!(matches!(blocked, AcquireOutcome::Blocked(_)));
}

#[test]
fn lock_session_reentrant_for_same_session() {
    let mut store = FileLockStore::open_in_memory().expect("store");

    let first = store
        .acquire_session("scripts/plan-db.sh", "session-a", "agent-a")
        .expect("first");
    assert_eq!(first, AcquireOutcome::Acquired);

    let second = store
        .acquire_session("scripts/plan-db.sh", "session-a", "agent-a")
        .expect("second");
    assert_eq!(second, AcquireOutcome::Reentrant);
}

#[test]
fn lock_release_session_unblocks_plan_lock() {
    let db = unique_db_path("release-session");
    let mut first = FileLockStore::open(&db).expect("first");
    let mut second = FileLockStore::open(&db).expect("second");

    let acquired = first
        .acquire_session("hooks/dispatcher.sh", "session-z", "agent-a")
        .expect("session lock");
    assert_eq!(acquired, AcquireOutcome::Acquired);

    let blocked = second
        .acquire_plan("hooks/dispatcher.sh", "T10-04", Some(100025), "agent-b")
        .expect("plan acquire");
    assert!(matches!(blocked, AcquireOutcome::Blocked(_)));

    let released = first.release_session("session-z").expect("release");
    assert_eq!(released, 1);

    let acquired_after = second
        .acquire_plan("hooks/dispatcher.sh", "T10-04", Some(100025), "agent-b")
        .expect("plan acquire after release");
    assert_eq!(acquired_after, AcquireOutcome::Acquired);
}

fn unique_db_path(label: &str) -> PathBuf {
    let suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("clock")
        .as_nanos();
    std::env::temp_dir().join(format!("claude-core-lock-{label}-{suffix}.db"))
}
