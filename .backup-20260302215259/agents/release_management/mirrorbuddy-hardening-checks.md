---
name: mirrorbuddy-hardening-checks
description: Production hardening validation for MirrorBuddy releases. Used by app-release-manager.
tools: ["Read", "Grep", "Glob", "Bash", "Task"]
version: "1.1.0"
memory: project
maxTurns: 20
---

# MirrorBuddy Production Hardening Checks

## When to Run

Run these checks before ANY release of MirrorBuddy:

- Version bumps
- Feature releases
- Hotfixes to production

## Hardening Checklist

### 1. Supply Chain Security

```bash
# Lock file present and committed
[ -f "package-lock.json" ] && echo "PASS: Lock file exists"

# No high vulnerabilities
npm audit --audit-level=high

# SBOM can be generated
npx @cyclonedx/cyclonedx-npm --output-file /tmp/sbom.json
```

**BLOCKING**: Missing lock file or high vulnerabilities

### 2. Container Build

```bash
# Dockerfile builds successfully
docker build -t mirrorbuddy:test . 2>&1

# Image size reasonable (< 500MB)
docker images mirrorbuddy:test --format "{{.Size}}"

# Health check configured
grep -q "HEALTHCHECK" Dockerfile
```

**BLOCKING**: Build failure

### 3. Observability

| Check             | Command                                 | Pass Criteria |
| ----------------- | --------------------------------------- | ------------- |
| Structured logger | `grep "JSON.stringify" src/lib/logger/` | Present       |
| Health endpoint   | `curl /api/health`                      | Returns JSON  |
| Detailed health   | `curl /api/health/detailed`             | Returns JSON  |

### 4. Documentation

| Document            | Location                                | Required |
| ------------------- | --------------------------------------- | -------- |
| SLI/SLO definitions | `docs/operations/SLI-SLO.md`            | Yes      |
| Incident runbook    | `docs/operations/RUNBOOK.md`            | Yes      |
| Procedures          | `docs/operations/RUNBOOK-PROCEDURES.md` | Yes      |
| Deferred items ADR  | `docs/adr/0037-*.md`                    | Yes      |

```bash
# Verify docs exist
for f in docs/operations/SLI-SLO.md docs/operations/RUNBOOK.md; do
  [ -f "$f" ] && echo "PASS: $f" || echo "FAIL: $f missing"
done
```

### 5. Performance Gates

```bash
# Lighthouse CI config present
[ -f "lighthouserc.js" ] && echo "PASS: Lighthouse config exists"

# Accessibility gates configured
grep -q "categories:accessibility" lighthouserc.js
```

### 6. Safety Systems

```bash
# Safety module present
ls src/lib/safety/jailbreak-detector.ts
ls src/lib/safety/content-filter.ts
ls src/lib/safety/age-gating.ts
ls src/lib/safety/output-sanitizer.ts

# Safety tests exist
ls src/lib/safety/__tests__/
```

**BLOCKING**: Missing safety modules

### 7. Error Handling

```bash
# Error boundary present
[ -f "src/components/error-boundary.tsx" ] && echo "PASS"

# Error boundary exported
grep -q "export.*ErrorBoundary" src/components/error-boundary.tsx
```

## Integration with app-release-manager

Add to Wave 2 of app-release-manager:

```
### Task J: MirrorBuddy Hardening (MirrorBuddy ONLY)
PROMPT: "MirrorBuddy production hardening check.
1. Lock file: [ -f package-lock.json ]
2. Docker: docker build -t test . (dry run check Dockerfile exists)
3. Docs: ls docs/operations/*.md
4. Safety: ls src/lib/safety/*.ts
5. Error boundary: [ -f src/components/error-boundary.tsx ]
Return JSON: {status: PASS/FAIL, missing: [...]}"
MODEL: haiku, BACKGROUND: true
```

## Maintenance Checklist (Post-Release)

After each release, verify:

- [ ] Lock file updated if dependencies changed
- [ ] SBOM artifact uploaded to CI
- [ ] Changelog updated
- [ ] ADR 0037 still accurate (items not yet implemented)
- [ ] SLI/SLO targets still appropriate

## Version History

| Version | Date       | Changes           |
| ------- | ---------- | ----------------- |
| 1.0.0   | 2025-01-11 | Initial checklist |
