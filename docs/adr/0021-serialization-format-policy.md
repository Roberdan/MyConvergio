# ADR 0021: Serialization Format Policy (JSON vs YAML)

Status: Accepted | Date: 27 Feb 2026

## Context

Planner moved to YAML (spec.yaml) for plan specifications. Digest scripts (14 total) output JSON. Question raised: should all output be unified to one format?

Analysis of the two use cases:

| Dimension   | Plan specs (YAML)            | Digest output (JSON)       |
| ----------- | ---------------------------- | -------------------------- |
| Authored by | Humans + agents              | Scripts only               |
| Consumed by | Import pipeline (plan-db.sh) | Agents (one-shot read)     |
| Lifespan    | Persistent (stored in DB)    | Transient (cached 5-120s)  |
| Editing     | Frequent (review, modify)    | Never                      |
| Tooling     | yq (available)               | jq (10yr stable ecosystem) |
| Token cost  | Matters (large specs)        | Low (already ~200 tokens)  |

Token comparison on representative digest output (~200 tokens JSON):

- JSON: `{"status":"ok","exit_code":0,"errors":[]}` = baseline
- YAML equivalent: `status: ok\nexit_code: 0\nerrors: []` = ~15-20% fewer tokens
- Absolute saving: ~30-40 tokens per digest call — marginal

## Decision

**YAML for config/specs authored by humans. JSON for machine-generated transient output.**

| Format | Use for                                               | Why                                                                     |
| ------ | ----------------------------------------------------- | ----------------------------------------------------------------------- |
| YAML   | Plan specs, settings, agent frontmatter, config files | Human-readable, token-efficient for large documents, editable           |
| JSON   | Digest output, API responses, cache, dashboard data   | jq ecosystem (stable, universal), programmatic generation, no ambiguity |

**Do NOT convert digest scripts to YAML.** Cost of migration (14 scripts + cache layer + hooks) far exceeds marginal token savings on already-compact output.

## Optimization Strategy (Digest Token Reduction)

Instead of format change, reduce tokens through content optimization:

1. **`--compact` flag**: Each digest supports `--compact` to omit non-decision-relevant fields (~30-40% fewer tokens)
2. **Field audit**: Remove redundant fields that echo input or duplicate other digests
3. **Aggregation**: `service-digest.sh all` runs 5 digests in parallel, single output

## Consequences

### Positive

- Clear policy prevents recurring "should we switch?" discussions
- `--compact` achieves better token savings than format change (~30-40% vs ~15-20%)
- No migration risk, no jq→yq rewrite, no cache invalidation
- Both formats serve their optimal use case

### Negative

- Two serialization formats in the ecosystem (intentional, documented)
- New contributors must understand the policy boundary
