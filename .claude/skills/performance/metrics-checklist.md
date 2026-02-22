# Performance Metrics Checklist

## Latency Metrics

- [ ] P50 (median) latency measured
- [ ] P95 latency (95th percentile) tracked
- [ ] P99 latency (worst case) monitored
- [ ] Max latency identified

## Throughput Metrics

- [ ] Requests per second (RPS) capacity known
- [ ] Transactions per second (TPS) measured
- [ ] Concurrent users handled documented
- [ ] Peak load capacity established

## Resource Metrics

- [ ] CPU utilization tracked (target: <70% at peak)
- [ ] Memory usage monitored (avoid swapping)
- [ ] Disk I/O measured (IOPS, throughput)
- [ ] Network bandwidth utilization tracked

## User Experience Metrics

- [ ] Time to First Byte (TTFB) < 200ms
- [ ] First Contentful Paint (FCP) < 1.8s
- [ ] Time to Interactive (TTI) < 3.8s
- [ ] Total Page Load < 3s
