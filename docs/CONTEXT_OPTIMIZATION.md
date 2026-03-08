# MyConvergio Context Optimization Guide (v11)

Use this guide to pick the right context tier and understand how orchestration components consume tokens.

## Quick Reference

| Profile | Agents | Rules | Context Usage | Best For |
| --- | --- | --- | --- | --- |
| **Minimal** | 9 core | Consolidated | ~50KB | Tight budgets, essential execution only |
| **Standard** | ~20 core | Consolidated | ~200KB | Daily development |
| **Full** | 65 | Full set | ~600KB | Complete ecosystem |
| **Lean** | 65 (optimized) | Consolidated | ~400KB | Full capability with lower token footprint |

## Tiered Context Components

Context is not only agent count; it is the sum of active orchestration roles and runtime artifacts.

| Tier | Component | Runtime Role | Cost Pattern |
| --- | --- | --- | --- |
| L1 | Core orchestrators (`planner`, `execute`, `validate`) | Planning, execution, Thor gate flow | Baseline, always-on during active plans |
| L2 | Domain specialists | Task-specific coding and analysis | Spiky, task-scoped |
| L3 | **night-agent** (`night-maintenance`) | Nightly issue triage and bounded remediation | Off-hours batch usage |
| L3 | **sync-agent** (`claude-sync` operational flow) | Ecosystem alignment and mesh sync operations | Periodic infra sync usage |
| L4 | Recovery + anti-compaction utilities | Checkpointing, restore, continuity | Burst usage at compaction boundaries |

## Installation Profiles

```bash
myconvergio install --minimal
myconvergio install --standard
myconvergio install --full
myconvergio install --lean
```

Equivalent Make targets:

```bash
make install-tier TIER=minimal
make install-tier TIER=standard
make install
make install-tier TIER=lean
```

## Hardware Settings

```bash
myconvergio settings
```

Templates:
- `low-spec.json` (8GB / 4 cores)
- `mid-spec.json` (16GB / 8 cores)
- `high-spec.json` (32GB+ / 10+ cores)

## Anti-Compaction Continuity

| Component | Location | Purpose |
| --- | --- | --- |
| `plan-checkpoint.sh` | `.claude/scripts/` | Save and restore active plan state |
| `preserve-context.sh` | `hooks/` | Pre-compact state preservation |

Recovery flow:

```bash
plan-checkpoint.sh restore <plan_id>
plan-db.sh execution-tree <plan_id>
cd <worktree_path>
```

## Recommended Baselines

- **Conservative**: Minimal + low-spec settings
- **Balanced**: Lean + mid-spec settings
- **Maximum**: Full + high-spec settings

## References

- [Getting Started](./getting-started.md)
- [Infrastructure](./infrastructure.md)
- [Workflow](./workflow.md)
