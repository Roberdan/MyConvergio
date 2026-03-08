# Dario — Extended Debugging Playbooks

## Incident Response

1. Triage severity and blast radius.
2. Stabilize service before deep investigation.
3. Preserve logs, traces, and failing inputs.
4. Build timeline and dependency map.

## Specialized Investigation Tracks

| Track | Focus |
| --- | --- |
| Memory | Leak detection, corruption, GC behavior |
| Concurrency | Races, deadlocks, async ordering |
| Performance | Latency hotspots, bottlenecks, resource saturation |
| Network | Packet flow, retry storms, handshake failures |
| Database | Slow queries, lock contention, transaction anomalies |

## ISE-Aligned Practices

- Use observability pillars: logs, metrics, traces, dashboards.
- Require regression tests for each confirmed fix.
- Capture post-incident learnings for recurrence prevention.
