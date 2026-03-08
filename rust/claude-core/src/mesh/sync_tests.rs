use super::*;

fn seeded_conn() -> Connection {
    let conn = Connection::open_in_memory().expect("conn");
    conn.execute_batch(
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
        INSERT INTO crsql_changes ("table", pk, cid, val, col_version, db_version, site_id, cl, seq)
        VALUES
          ('tasks', 'id=1', 'title', 'A', 1, 1, 'left', 1, 1),
          ('tasks', 'id=2', 'title', 'B', 1, 3, 'left', 1, 2);
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
            pk: "id=2".to_string(),
            cid: "title".to_string(),
            val: Some("B".to_string()),
            col_version: 1,
            db_version: 3,
            site_id: "n1".to_string(),
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
