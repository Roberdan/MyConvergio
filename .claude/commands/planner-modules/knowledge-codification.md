---
name: knowledge-codification
version: "1.0.0"
---

# Knowledge Codification Workflow

## MANDATORY: Before closing any plan

Every error/learning MUST be documented in ADR + codified in ESLint rules.
Thor validates before closure.

## 0. Per-Wave Documentation (EVERY wave, not optional)

Each wave's **final task** (TX-doc, model=haiku) updates two files:

### CHANGELOG.md (incremental)

```markdown
## [Unreleased]

### WX: {wave name}

- Added: {feature/file}
- Changed: {modification}
- Fixed: {bug}
- Learnings: {brief note, ref ADR if created}
```

### Running Notes (`docs/adr/plan-{id}-notes.md`)

```markdown
# Plan {id} Running Notes

## W1: {wave name}

- Decision: {what and why, 1 line}
- Issue: {problem} → Fix: {solution}
- Pattern: {reusable insight}

## W2: {wave name}

...
```

These notes feed the FINAL wave ADR creation. Skipping = Thor blocks closure.

## 1. Learnings Log (Update During Execution)

In plan file, maintain:

```markdown
## LEARNINGS LOG

| Wave | Issue               | Root Cause       | Resolution                | Preventive Rule |
| ---- | ------------------- | ---------------- | ------------------------- | --------------- |
| W1   | Import circolare    | A→B→A cycle      | Extracted shared types    | no-cycle        |
| W1   | Cookie non validato | Raw cookie.value | Added validateVisitorId() | grep pre-commit |
```

**What to document**:

- Errors during execution
- Test false positives/negatives
- Problematic patterns
- Non-obvious architectural decisions
- Temporary workarounds (to remove!)

## 2. Create ADRs (compact format, max 20 lines)

For each significant learning, create ADR in `docs/adr/`:

```markdown
# ADR {NNNN}: {Title}

Status: Accepted | Date: {DD Mon YYYY} | Plan: {plan_id}

## Context

{2-3 sentences: what problem, when encountered}

## Decision

{2-3 sentences: what we chose, why}

## Consequences

- Positive: {outcome}
- Negative: {tradeoff}

## Enforcement

- Rule: `{eslint-rule-or-grep-pattern}`
- Check: `{verification command}`
- Ref: {related ADR IDs if any}
```

**Format rules**:

- Max 20 lines per ADR. No prose filler.
- Status/Date/Plan on ONE line (grep-friendly)
- Consequences use `Positive:`/`Negative:` labels (grep-friendly)
- Enforcement MUST include a runnable check command
- One ADR per decision. Don't merge unrelated learnings.

## 3. Create ESLint Rules

For automatable learnings:

```javascript
// eslint.config.mjs
{
  rules: {
    // ADR-0XXX: {short description}
    "no-restricted-syntax": ["error", {
      selector: "...",
      message: "ADR-0XXX: {message}"
    }]
  }
}
```

**Rule types**:

- `no-restricted-imports`: Forbidden imports
- `no-restricted-syntax`: Forbidden AST patterns
- Custom rule in `eslint-local-rules/`: Complex logic

## 4. Thor Validates Codification

```typescript
Task({
  subagent_type: "thor-quality-assurance-guardian",
  prompt: `Validate Knowledge Codification for Plan {plan_id}.

  LEARNINGS from plan: [list from LEARNINGS LOG]

  VERIFY:
  1. ADR exists for each significant learning (compact format, max 20 lines)
  2. ESLint rule exists for each automatable learning
  3. ESLint rule WORKS: create temp test file with forbidden pattern, verify lint fails
  4. Pre-commit hook includes new rules (if applicable)
  5. CHANGELOG updated with per-wave entries
  6. Running notes exist at docs/adr/plan-{id}-notes.md

  FAIL if: ADR missing, rule doesn't work, learning not codified`,
});
```

## 5. Pre-Closure Checklist

| Check                                            | Verified |
| ------------------------------------------------ | -------- |
| Per-wave CHANGELOG entries present for all waves | [ ]      |
| Running notes file exists with entries per wave  | [ ]      |
| All learnings have ADR (if significant)          | [ ]      |
| All automatable learnings have ESLint rule       | [ ]      |
| Each ESLint rule has test case that FAILS        | [ ]      |
| Thor validated codification                      | [ ]      |

**BLOCKED if any check is [ ]**

## Anti-Failure Rules

- **NEVER close plan without Knowledge Codification**
- **NEVER skip per-wave documentation** — every wave updates CHANGELOG + notes
- **NEVER skip ESLint rule testing** — ogni regola deve avere test case che FALLISCE
- **Learnings not codified = plan NOT done** — Thor blocks closure if missing
