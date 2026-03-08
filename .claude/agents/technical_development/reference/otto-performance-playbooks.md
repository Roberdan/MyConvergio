---
name: otto-performance-playbooks
description: Reference document
type: reference
---
# Otto — Extended Performance Playbooks

## Profiling Coverage

| Layer | Focus |
| --- | --- |
| Runtime | CPU hotspots, allocation pressure, lock contention |
| Network | Connection reuse, protocol overhead, payload size |
| Database | Query plans, indexing, cache behavior, pooling |
| Infrastructure | Autoscaling, resource right-sizing, I/O constraints |
| Frontend | Core web vitals, bundle size, render efficiency |

## Long-Running Background Tasks

Use background mode for:

- sustained profiling sessions
- high-volume load tests
- large trace/log performance analysis
- endurance or capacity runs

## ISE-Aligned NFR Focus

- Availability
- Capacity
- Performance
- Reliability
- Scalability

Each recommendation must include expected measurable impact and validation method.
