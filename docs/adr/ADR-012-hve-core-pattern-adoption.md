# ADR-012: HVE Core Pattern Adoption

## Status

Accepted

## Context

During analysis of HVE Core patterns, we identified several practices that could enhance MyConvergio's agent catalog quality, consistency, and provider compatibility. The HVE Core project demonstrated mature patterns for agent specification, validation, and lifecycle management that align with our goals for a provider-agnostic, high-quality agent ecosystem.

Key observations:
- Need for formalized agent specification validation
- Desire for clear maturity signals across agent catalog
- Requirement for explicit constraint documentation
- Growing complexity in agent handoff scenarios
- Multi-provider support (Claude, GitHub Copilot, OpenCode, Gemini)

## Decision

We adopt **five patterns inspired by HVE Core**, plus one MyConvergio-original extension:

### 1. JSON Schema Frontmatter Validation
- Enforce structured metadata in agent specifications via JSON Schema
- Validate required fields (name, version, description, providers)
- Enable automated quality gates during agent registration

### 2. Maturity Lifecycle
- Classify agents by maturity: `experimental` → `beta` → `stable` → `deprecated`
- Surface maturity in agent catalog UI
- Guide users toward production-ready agents

### 3. Explicit Constraints
- Document resource limits (token budgets, timeout thresholds)
- Declare safety boundaries (PII handling, external API usage)
- Enable pre-execution validation

### 4. Agent Handoffs
- Formalize orchestration patterns for multi-agent workflows
- Define handoff contracts (context, expected outputs)
- Support composition patterns (sequential, parallel, conditional)

### 5. Structured Tracking
- Embed execution metadata (session IDs, parent tasks, timestamps)
- Enable audit trails and workflow debugging
- Support analytics on agent usage patterns

### 6. Provider Compatibility Declaration (MyConvergio Original)
- Introduce `providers` field in agent frontmatter
- Declare compatibility with: `claude`, `copilot`, `opencode`, `gemini`
- Enable provider-specific optimizations while maintaining portability
- Guide users to agents matching their environment

## Consequences

### Positive
- **Enhanced Quality Gates**: JSON Schema validation catches specification errors early
- **Safety Constraints**: Explicit resource/safety boundaries reduce risk
- **Guided Workflows**: Maturity lifecycle helps users select appropriate agents
- **Provider Awareness**: `providers` field enables multi-provider catalog with clear compatibility signals
- **Observability**: Structured tracking supports debugging and optimization
- **Composability**: Handoff patterns enable sophisticated multi-agent workflows

### Negative
- **Increased Specification Overhead**: Agent authors must populate more metadata fields
- **Migration Effort**: Existing agents require frontmatter updates
- **Tooling Dependencies**: Need validation infrastructure (JSON Schema processor)

### Neutral
- **Inspired, Not Cloned**: We adapt HVE Core patterns to MyConvergio's provider-agnostic design rather than direct replication
- **Provider List**: Initial `providers` support covers Claude, Copilot, OpenCode, Gemini; extensible to future platforms

## Implementation Notes

1. Create JSON Schema for agent frontmatter validation
2. Update agent catalog to display maturity badges
3. Add `providers` field to specification template
4. Document constraint syntax in agent authoring guide
5. Build handoff validation into orchestration layer
6. Instrument tracking hooks in agent execution runtime

## References

- F-12: HVE Core Pattern Analysis
- HVE Core repository (pattern source)
- MyConvergio Agent Catalog specification
