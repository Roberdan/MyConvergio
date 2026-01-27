# Knowledge Codification Workflow

## MANDATORY: Before closing any plan

Every error/learning MUST be documented in ADR + codified in ESLint rules.
Thor validates before closure.

## 1. Learnings Log (Update During Execution)

In plan file, maintain:

```markdown
## LEARNINGS LOG
| Wave | Issue | Root Cause | Resolution | Preventive Rule |
|------|-------|------------|------------|-----------------|
| W1 | Import circolare | A importava B che importava A | Estratto tipo in file condiviso | eslint-plugin-import/no-cycle |
| W1 | Cookie non validato | Usato cookie.value senza check | Aggiunto validateVisitorId() | Grep rule in pre-commit |
```

**What to document**:
- Errors during execution
- Test false positives/negatives
- Problematic patterns
- Non-obvious architectural decisions
- Temporary workarounds (to remove!)

## 2. Create/Update ADR

For each significant learning, create ADR in `docs/adr/`:

```markdown
# ADR {NNNN}: {Learning Title}

## Status
Accepted

## Context
[Problem encountered during Plan {ID}]

## Decision
[Solution adopted]

## Consequences
- [Positive]: Prevents regression X
- [Negative]: Requires Y extra

## Enforcement
- ESLint rule: `{rule-name}`
- Pre-commit check: `{script}`
```

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
  1. ADR exists for each significant learning
  2. ESLint rule exists for each automatable learning
  3. ESLint rule WORKS: create temp test file with forbidden pattern, verify lint fails
  4. Pre-commit hook includes new rules (if applicable)
  5. CHANGELOG updated with ADR link

  TEST COMMAND:
  echo "forbidden pattern" > /tmp/test-rule.ts
  npm run lint /tmp/test-rule.ts 2>&1 | grep -q "ADR-XXXX" || echo "RULE NOT WORKING"

  FAIL if: ADR missing, rule doesn't work, learning not codified`
});
```

## 5. Pre-Closure Checklist

| Check | Verified |
|-------|----------|
| All learnings have ADR (if significant) | [ ] |
| All automatable learnings have ESLint rule | [ ] |
| Each ESLint rule has test case that FAILS | [ ] |
| CHANGELOG updated with "Learnings" section | [ ] |
| Thor validated codification | [ ] |

**BLOCKED if any check is [ ]**

## Anti-Failure Rules

- **NEVER close plan without Knowledge Codification**
- **NEVER skip ESLint rule testing** - ogni regola deve avere test case che FALLISCE
- **Learnings not codified = plan NOT done** - Thor blocks closure if missing
