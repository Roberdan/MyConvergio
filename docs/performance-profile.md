# Mesh Performance Profile — Plan 599

## Binary Size
| Build | Size |
|-------|------|
| Release (macOS arm64) | ~8.5 MB |
| Debug | ~45 MB |

## Memory Footprint (idle daemon)
- RSS: ~12 MB
- Virtual: ~400 MB (Tokio runtime pre-allocated)
- Per-peer connection: ~64 KB (buffers + TLS state)

## CRDT Sync Throughput
| Metric | Value | Notes |
|--------|-------|-------|
| apply_changes_to_conn (1000 changes) | <50ms | stress_apply_1000_changes test |
| Delta frame encode (msgpack) | <1ms per frame | rmp_serde::to_vec_named |
| Delta frame decode | <1ms per frame | rmp_serde::from_slice |
| Heartbeat cycle | 5s | Configurable |
| Anti-entropy catch-up | 1000 rows/tick | LIMIT 1000, 2s ticks |

## Atomic Counters (MeshMetrics)
- 10 threads × 100 increments = 1000 total: <5ms
- Zero-contention via Ordering::Relaxed
- No mutex overhead on hot paths

## Rate Limiter
- Per-IP check: O(n) where n = requests in window (max 60)
- Sliding window cleanup: automatic on check
- Concurrent tracking: HashMap lookup O(1)

## Bottlenecks Identified
1. **LogBuffer**: Uses Mutex + Vec::remove(0) = O(n) shift. Consider VecDeque for O(1) pop_front.
2. **CRDT allowlist**: Re-queries sqlite_master on every apply. Cache for 60s.
3. **Anti-entropy**: Full table scan on catch-up. Index on db_version recommended.

## Optimization Roadmap
- [ ] Replace LogBuffer Vec with VecDeque (eliminates O(n) shift)
- [ ] Cache CRDT allowlist with 60s TTL
- [ ] Add db_version index to crsql_changes
- [ ] Profile with `cargo flamegraph` under sustained load
