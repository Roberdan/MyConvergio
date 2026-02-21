---
name: performance
description: Data-driven performance optimization through profiling and infrastructure tuning
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
context: fork
user-invocable: true
version: "2.0.0"
---

# Performance Optimization Skill

> Reusable workflow extracted from otto-performance-optimizer expertise.

Systematically identify and eliminate performance bottlenecks through data-driven profiling, algorithmic optimization, and infrastructure tuning.

## When to Use

Performance degradation | Pre-release validation | Scalability planning | High-load optimization | Cost optimization | Database tuning | Frontend Core Web Vitals | Infrastructure right-sizing

## Workflow

| Step | Actions |
|------|---------|
| **1. Define Goals** | Specific targets (P95 < 200ms), throughput (req/sec), resource efficiency, UX requirements, baseline |
| **2. Baseline** | Reproducible benchmarks, measure key metrics, representative workloads, document environment |
| **3. Profile** | CPU (hot paths), Memory (leaks, GC), I/O (disk/network), Database (EXPLAIN), Frontend (Lighthouse) |
| **4. Bottlenecks** | Analyze profiling data, root causes vs symptoms, quantify impact, prioritize by impact/effort |
| **5. Prioritize** | Quick Wins (high/low), Strategic (high/med), Incremental (med/low), Deferred (low/high) |
| **6. Implement** | Incremental changes, measure independently, before/after metrics, verify no regressions |
| **7. Validate** | Compare vs baseline/goals, load tests at scale, edge cases, resource utilization, cost |
| **8. Monitor** | Performance dashboards, degradation alerts, CI/CD tests, document decisions, review cadence |

## Inputs

- Performance targets (latency, throughput, resources)
- Current metrics (baseline)
- Workload profile (traffic patterns, peak loads)
- Constraints (budget, timeline, trade-offs)
- Environment (production specs, infrastructure)

## Outputs

- Profiling Report (flame graphs, bottlenecks)
- Optimization Roadmap (prioritized with impact)
- Before/After Benchmarks
- Capacity Plan
- Monitoring Setup (metrics, dashboards, alerts)
- Cost Analysis

## Profiling Tools

| Category | Tools |
|----------|-------|
| **CPU** | Python: cProfile, py-spy • JS/Node: Chrome DevTools, clinic.js, 0x • C/C++: Instruments, perf, Valgrind • Java: JProfiler, JFR • Go: pprof |
| **Memory** | Python: memory_profiler, tracemalloc • JS/Node: heap profiler • C/C++: Valgrind, ASan • Java: VisualVM • Go: pprof heap |
| **Database** | PostgreSQL: EXPLAIN ANALYZE, pg_stat_statements • MySQL: EXPLAIN, slow log • MongoDB: explain() • Redis: SLOWLOG |
| **System** | Linux: perf, eBPF, sysstat • macOS: Instruments, dtrace • Network: Wireshark, tcpdump |

## Optimization Strategies

### Algorithmic

- Complexity: O(n²) → O(n log n) → O(n)
- Data structures: Array vs Hash vs Tree
- Caching: Memoization, computed properties
- Lazy evaluation: Compute on demand
- Batch processing: Avoid N+1 queries

### Database

- Query optimization: Rewrite inefficient queries
- Indexes: B-tree, hash, partial, covering
- Connection pooling: 2-10× CPU cores
- Batching: Combine queries
- Denormalization: Trade-off for reads
- Caching: Redis/Memcached for hot data

### Frontend

- **Core Web Vitals**: LCP < 2.5s, FID < 100ms, CLS < 0.1
- Bundle: Code splitting, tree shaking, lazy loading
- Assets: Compression, WebP, responsive images
- Caching: Service workers, Cache-Control
- CDN: Geographic distribution, edge caching

### Backend

- API: Reduce payload, compression
- Async: Queue long tasks
- Connection reuse: HTTP keep-alive, pooling
- Caching layers: App, CDN, DB
- Concurrency: async/await, workers

### Infrastructure

- Auto-scaling: Horizontal/vertical policies
- Right-sizing: Match actual usage
- Load balancing: Distribute efficiently
- Geo-distribution: Multi-region
- Resource limits: Prevent exhaustion

## Metrics Checklist

See [metrics-checklist.md](./metrics-checklist.md) for latency, throughput, resource, and UX metrics.

## Example

```
Input: /api/users P95: 3.2s, target: <200ms

Steps:
1. Goal: P95 < 200ms, throughput 5x
2. Baseline: P95 = 3.2s, 50 req/sec
3. Profile: 80% in DB query, full table scan, no index
4. Bottleneck: Missing index, N+1 pattern
5. Prioritize: Add index (quick), fix N+1 (quick), cache (strategic)
6. Implement: CREATE INDEX, rewrite query, Redis (TTL: 5min)
7. Validate: P95 = 45ms (98.6% ↓), 400 req/sec (8x ↑), DB CPU 85% → 12%
8. Monitor: Grafana dashboard, alert if P95 > 200ms

Output: ✅ P95 = 45ms, ✅ 400 req/sec, ✅ $2,400/mo saved
```

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| Premature optimization | Profile first, then optimize |
| Micro-optimizations | Focus on measurable user impact |
| Benchmark gaming | Use production-like workloads |
| Complexity creep | Balance performance vs maintainability |
| Ignoring trade-offs | Document explicitly |

## Performance Budget

```markdown
## [Feature/Page]

### Targets
- P95: < [x]ms
- Throughput: > [x] req/sec
- Page Load: < [x]s
- Bundle: < [x]KB

### Current
- P95: [y]ms
- Status: ✅/❌

### Action
[Optimization plan if exceeded]
```

## Related Agents

- **otto-performance-optimizer** - Full profiling expertise
- **baccio-tech-architect** - Architecture-level design
- **dario-debugger** - Performance bug investigation
- **omri-data-scientist** - ML inference optimization
- **marco-devops-engineer** - Infrastructure tuning

## Engineering Fundamentals

- Observability: metrics, tracing for performance
- Load testing: validates peak load behavior
- Performance testing: measures vs baselines
- Stress testing: finds breaking points
- NFRs: SLAs defined upfront
- Parametrize: easy configuration tuning
- Log durations: critical paths
- Realistic load: not just happy-path
