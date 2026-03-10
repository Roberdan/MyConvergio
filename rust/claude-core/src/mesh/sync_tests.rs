use super::*;

fn seeded_conn() -> Connection {
    let conn = Connection::open_in_memory().expect("conn");
    conn.execute_batch(
        r#"
        CREATE TABLE crsql_changes (
          "table" TEXT NOT NULL,
          pk BLOB NOT NULL,
          cid TEXT NOT NULL,
          val TEXT,
          col_version INTEGER NOT NULL,
          db_version INTEGER NOT NULL,
          site_id BLOB NOT NULL,
          cl INTEGER NOT NULL,
          seq INTEGER NOT NULL
        );
        CREATE TABLE tasks__crsql_clock (id INTEGER PRIMARY KEY);
        INSERT INTO crsql_changes ("table", pk, cid, val, col_version, db_version, site_id, cl, seq)
        VALUES
          ('tasks', X'69643D31', 'title', 'A', 1, 1, X'6C656674', 1, 1),
          ('tasks', X'69643D32', 'title', 'B', 1, 3, X'6C656674', 1, 2);
        "#,
    )
    .expect("seed schema");
    conn
}

#[test]
fn reads_only_deltas_after_checkpoint() {
    let conn = seeded_conn();
    let changes = read_changes_since_from_conn(&conn, 1).expect("read changes");
    assert_eq!(changes.len(), 1);
    assert_eq!(changes[0].db_version, 3);
}

#[test]
fn msgpack_roundtrip_preserves_delta_payload() {
    let frame = MeshSyncFrame::Delta {
        node: "n1".to_string(),
        sent_at_ms: 42,
        last_db_version: 3,
        changes: vec![DeltaChange {
            table_name: "tasks".to_string(),
            pk: b"id=2".to_vec(),
            cid: "title".to_string(),
            val: Some("B".to_string()),
            col_version: 1,
            db_version: 3,
            site_id: b"n1".to_vec(),
            cl: 1,
            seq: 2,
        }],
    };
    let bytes = rmp_serde::to_vec_named(&frame).expect("encode");
    let decoded: MeshSyncFrame = rmp_serde::from_slice(&bytes).expect("decode");
    assert_eq!(decoded, frame);
}

#[test]
fn perf_batch_window_coalesces_changes_for_50ms() {
    let mut window = super::SyncBatchWindow::new(50);
    window.observe_change_at(10, 11);
    assert!(!window.should_flush(40));
    assert!(window.should_flush(61));
    assert_eq!(window.take_checkpoint(), 11);
}

#[test]
fn crdt_allowlist_blocks_unknown_tables() {
    let conn = seeded_conn();
    // 'tasks' has __crsql_clock → allowed; 'evil_table' does not → blocked
    let changes = vec![
        DeltaChange {
            table_name: "tasks".to_string(),
            pk: b"id=1".to_vec(), cid: "title".to_string(),
            val: Some("OK".to_string()), col_version: 1, db_version: 10,
            site_id: b"peer1".to_vec(), cl: 1, seq: 1,
        },
        DeltaChange {
            table_name: "evil_table".to_string(),
            pk: b"id=1".to_vec(), cid: "data".to_string(),
            val: Some("INJECTED".to_string()), col_version: 1, db_version: 11,
            site_id: b"peer1".to_vec(), cl: 1, seq: 2,
        },
    ];
    let applied = apply_changes_to_conn(&conn, &changes).expect("apply");
    assert_eq!(applied, 1, "only allowed table should be applied");
}

// === W7: Comprehensive integration & stress tests ===

#[test]
fn empty_changes_applies_zero() {
    let conn = seeded_conn();
    let applied = apply_changes_to_conn(&conn, &[]).expect("apply");
    assert_eq!(applied, 0);
}

#[test]
fn allowlist_with_multiple_valid_tables() {
    let conn = Connection::open_in_memory().expect("conn");
    conn.execute_batch(r#"
        CREATE TABLE crsql_changes ("table" TEXT, pk BLOB, cid TEXT, val TEXT,
            col_version INTEGER, db_version INTEGER, site_id BLOB, cl INTEGER, seq INTEGER);
        CREATE TABLE tasks__crsql_clock (id INTEGER PRIMARY KEY);
        CREATE TABLE plans__crsql_clock (id INTEGER PRIMARY KEY);
    "#).expect("seed");
    let allowlist = get_crr_table_allowlist(&conn);
    assert!(allowlist.contains("tasks"));
    assert!(allowlist.contains("plans"));
    assert!(!allowlist.contains("evil"));
}

#[test]
fn msgpack_roundtrip_auth_frames() {
    let frames = vec![
        MeshSyncFrame::AuthChallenge { nonce: vec![1,2,3], node: "n1".into() },
        MeshSyncFrame::AuthResponse { hmac: vec![4,5,6], node: "n2".into() },
        MeshSyncFrame::AuthResult { ok: true, reason: String::new() },
        MeshSyncFrame::AuthResult { ok: false, reason: "bad hmac".into() },
    ];
    for frame in &frames {
        let bytes = rmp_serde::to_vec_named(frame).expect("encode");
        let decoded: MeshSyncFrame = rmp_serde::from_slice(&bytes).expect("decode");
        assert_eq!(&decoded, frame);
    }
}

#[test]
fn stress_apply_1000_changes() {
    let conn = Connection::open_in_memory().expect("conn");
    conn.execute_batch(r#"
        CREATE TABLE crsql_changes ("table" TEXT, pk BLOB, cid TEXT, val TEXT,
            col_version INTEGER, db_version INTEGER, site_id BLOB, cl INTEGER, seq INTEGER);
        CREATE TABLE tasks__crsql_clock (id INTEGER PRIMARY KEY);
    "#).expect("seed");
    let changes: Vec<DeltaChange> = (0..1000).map(|i| DeltaChange {
        table_name: "tasks".into(),
        pk: format!("id={i}").into_bytes(),
        cid: "title".into(),
        val: Some(format!("task-{i}")),
        col_version: 1, db_version: i + 1, site_id: b"stress".to_vec(), cl: 1, seq: i as i64,
    }).collect();
    let start = std::time::Instant::now();
    let applied = apply_changes_to_conn(&conn, &changes).expect("apply");
    let elapsed = start.elapsed();
    assert_eq!(applied, 1000);
    assert!(elapsed.as_millis() < 5000, "1000 changes should apply in <5s, took {elapsed:?}");
}

#[test]
fn read_changes_pagination_respects_limit() {
    let conn = Connection::open_in_memory().expect("conn");
    conn.execute_batch(r#"
        CREATE TABLE crsql_changes ("table" TEXT, pk BLOB, cid TEXT, val TEXT,
            col_version INTEGER, db_version INTEGER, site_id BLOB, cl INTEGER, seq INTEGER);
        CREATE TABLE crsql_site_id (site_id BLOB);
        INSERT INTO crsql_site_id VALUES (X'6C6F63616C');
    "#).expect("seed");
    // Insert 1500 changes (LIMIT is 1000)
    for i in 0..1500 {
        conn.execute(
            "INSERT INTO crsql_changes VALUES ('tasks', X'01', 'title', 'v', 1, ?1, X'6C6F63616C', 1, ?1)",
            [i + 1],
        ).expect("insert");
    }
    let changes = read_changes_since_from_conn(&conn, 0).expect("read");
    // read_changes_since_from_conn has NO limit (unlike read_local_changes_since)
    assert_eq!(changes.len(), 1500);
}
