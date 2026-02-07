# Plan 130 Running Notes

## W1-Foundation: Distributed Execution

### Decisions

- **Separated cluster logic**: Created `plan-db-cluster.sh` module to keep `plan-db-crud.sh` under 250 lines
- **Atomic claim protocol**: Uses SQL WHERE clause for host check (no file locking needed)
- **Config sync check**: Leverages existing git bundle-based `csync push` infrastructure
- **Heartbeat + SSH fallback**: Best-effort heartbeat combined with on-demand SSH liveness check

### Issues

- **T1-05 blocked by T1-04**: Parallel execution revealed dependency ordering matters (cmd_start refactor needed cmd_claim from cluster module)

### Patterns

- SQL-based atomicity preferred over file locking for cross-host coordination
- Modular separation keeps individual scripts maintainable
- Reuse existing infrastructure (csync) rather than inventing new mechanisms
