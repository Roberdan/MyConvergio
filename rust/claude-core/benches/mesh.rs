use claude_core::mesh::sync::{DeltaChange, MeshSyncFrame};
use std::time::Instant;

fn main() {
    run_bench("db_sync", 500, bench_db_sync);
    run_bench("agent_heartbeat", 1_000, bench_heartbeat);
    run_bench("brain_event", 1_000, bench_brain_event);
}

fn run_bench(name: &str, rounds: usize, mut bench: impl FnMut()) {
    let mut samples = Vec::with_capacity(rounds);
    for _ in 0..rounds {
        let start = Instant::now();
        bench();
        samples.push(start.elapsed().as_micros() as u64);
    }
    samples.sort_unstable();
    let p50_ms = percentile_us(&samples, 0.50) as f64 / 1000.0;
    let p99_ms = percentile_us(&samples, 0.99) as f64 / 1000.0;
    println!("mesh_bench[{name}] p50={p50_ms:.3}ms p99={p99_ms:.3}ms");
}

fn percentile_us(samples: &[u64], p: f64) -> u64 {
    if samples.is_empty() {
        return 0;
    }
    let idx = ((samples.len() - 1) as f64 * p).round() as usize;
    samples[idx]
}

fn bench_db_sync() {
    let frame = MeshSyncFrame::Delta {
        node: "peer-a".to_string(),
        sent_at_ms: 1,
        last_db_version: 100,
        changes: vec![DeltaChange {
            table_name: "tasks".to_string(),
            pk: "id=1".to_string(),
            cid: "status".to_string(),
            val: Some("done".to_string()),
            col_version: 1,
            db_version: 100,
            site_id: "peer-a".to_string(),
            cl: 1,
            seq: 1,
        }; 64],
    };
    let encoded = rmp_serde::to_vec_named(&frame).expect("encode");
    let _: MeshSyncFrame = rmp_serde::from_slice(&encoded).expect("decode");
}

fn bench_heartbeat() {
    let frame = MeshSyncFrame::Heartbeat {
        node: "peer-a".to_string(),
        ts: 1_772_900_000,
    };
    let encoded = rmp_serde::to_vec_named(&frame).expect("encode");
    let _: MeshSyncFrame = rmp_serde::from_slice(&encoded).expect("decode");
}

fn bench_brain_event() {
    let payload = serde_json::json!({
        "kind": "agent_heartbeat",
        "node": "peer-a:9420",
        "ts": 1_772_900_000_u64,
        "payload": {"event_type": "heartbeat", "task_db_id": 6812, "tokens_total": 1200}
    });
    let line = payload.to_string();
    let _: serde_json::Value = serde_json::from_str(&line).expect("decode json");
}
