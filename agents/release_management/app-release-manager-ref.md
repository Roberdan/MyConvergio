# App Release Manager - Reference

> Task prompts and protocols for app-release-manager.md

**Last Updated**: 3 Gennaio 2026, 18:50 CET

---

## WAVE 1: Core Checks

### A: Build
Detect build system, run build, report PASS/FAIL.
- Node: `npm run build`, Rust: `cargo build --release`, Go: `go build ./...`
- BLOCKING: Any build error

### B: Security
Scan for secrets and vulnerabilities.
- `grep -rE "password|secret|api_key|AKIA[0-9A-Z]{16}"`
- `npm audit` / `cargo audit`
- BLOCKING: Hardcoded credentials, CVSS >= 7.0

### C: Code Quality
- `grep -rn "TODO\|FIXME"` → BLOCKING
- `grep -rn "console.log" src/` → BLOCKING
- Commented code, debug flags → WARNING

### D: Tests
- Run: `npm test`, Check: `npm run coverage`
- BLOCKING: Failed tests, coverage < 80%

### E: Documentation
- README.md exists with content
- CHANGELOG.md follows Keep a Changelog
- BLOCKING: Missing README

---

## WAVE 2: Infrastructure

### F: Dependencies
- `npm outdated`, check licenses
- BLOCKING: Known vulnerability

### G: Repository Hygiene
- .gitignore complete, no binary files, no conflicts
- BLOCKING: Secrets in history

### H: Version Consistency
- package.json = VERSION = CHANGELOG
- BLOCKING: Version mismatch

### I: AI Models (if applicable)
- No deprecated models
- WARNING: Outdated model version

---

## WAVE 3: ConvergioEdu

### J: Accessibility (WCAG 2.1 AA)
- axe-core scan, 4.5:1 contrast, alt text, keyboard nav
- BLOCKING: Level A violation

### K: GDPR (Minors)
- Parental consent, data minimization, no tracking without consent
- BLOCKING: Missing consent flows

### L: AI Safety
- Content filters, age-appropriate, no PII in context
- BLOCKING: Missing filters

### M: Educational Content
- Educator reviewed, curriculum aligned
- WARNING: Missing alignment

### N: E2E Flows
- Student registration → lesson → assessment → progress
- BLOCKING: Critical flow broken

---

## AUTO-FIX

```bash
# Remove console.log
find src -name "*.ts" | xargs sed -i '' '/console\.log/d'

# List TODOs
grep -rn "TODO\|FIXME" --include="*.ts" -A2 -B2

# Update deps safely
npm outdated && npm update --save
```

---

## LEARNINGS (2026-01-03)

### False Completion Pattern
Plans marked "COMPLETED" with unchecked internal tasks.
```bash
grep -l "COMPLETED" docs/plans/*.md | xargs grep -c '\[ \]'
```

### Smoke Test Deception
Tests that only check "no crash" without assertions.
**Bad**: `await page.click('btn')` (no assertion)
**Good**: `await expect(page.locator('.result')).toContainText('Success')`

---

## VERSION BUMP

| Change | Bump |
|--------|------|
| Breaking | MAJOR |
| Feature | MINOR |
| Fix | PATCH |

Update: package.json, VERSION, CHANGELOG.md

---

## REPORT FORMAT

```markdown
# Release Readiness Report
**Project**: X | **Version**: Y | **Date**: DD Mese YYYY, HH:MM CET | **Status**: APPROVED/BLOCKED

| Wave | Checks | Status |
|------|--------|--------|
| 1 | Build, Security, Quality, Tests, Docs | |
| 2 | Deps, Hygiene, Versions, AI | |
| 3 | A11y, GDPR, Safety, Content, E2E | |

## Blocking Issues
## Warnings
## Recommendation
```
