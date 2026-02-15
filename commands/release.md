## <!-- v2.0.0 -->

name: release
version: "2.0.0"

---

# Release Manager

Pre-release validation via `app-release-manager` subagent.

## Context (pre-computed)

```
Project: `basename "$(pwd)"`
Branch: `git branch --show-current 2>/dev/null || echo "not a git repo"`
Uncommitted: `git status --short 2>/dev/null | wc -l | tr -d ' '` files
Version: `node -p "require('./package.json').version" 2>/dev/null || echo "unknown"`
```

## Activation

`/release` or `/release {version}`

## Validation Checklist

Agent validates:

1. **Build Quality** — lint, typecheck, build passes
2. **Test Execution** — unit, integration, E2E tests
3. **Security Audit** — secrets, dependencies, vulnerabilities
4. **Code Quality** — no TODOs, debug prints, commented code
5. **Documentation** — CHANGELOG, README up to date

## Workflow

### Phase 1: Launch Agent

```typescript
await Task({
  subagent_type: "app-release-manager",
  description: "Release validation",
  prompt: `RELEASE VALIDATION

Project: ${project}
Target Version: ${version || "auto-detect from package.json"}
Branch: ${branch}

Execute full release gate:
1. Pre-flight checks (git clean, correct branch)
2. Build validation (lint, typecheck, build)
3. Test execution (unit, E2E)
4. Security audit (secrets, dependencies)
5. Code quality gates
6. Documentation review (CHANGELOG)

Zero tolerance policy:
- ANY test failure = BLOCK
- ANY security issue = BLOCK
- ANY lint error = BLOCK

Output: Release report with APPROVE or BLOCK decision.`,
});
```

### Phase 2: Review Results

Agent returns:

- All checks with pass/fail status
- Auto-fixes applied (if any)
- Blocking issues list (if any)
- Recommended next steps

### Phase 3: User Decision

**If APPROVED**:

- Confirm version bump (major/minor/patch)
- Create git tag
- Update CHANGELOG
- Optional: create GitHub release

**If BLOCKED**:

- Fix listed issues
- Re-run `/release`

## Zero Tolerance (Blocking)

- BLOCK: ANY compiler/lint warning
- BLOCK: ANY test failure
- BLOCK: ANY security vulnerability
- BLOCK: ANY TODO/FIXME in code
- BLOCK: ANY hardcoded secrets
- BLOCK: ANY debug prints (console.log)
- BLOCK: ANY outdated deps with CVEs

## Auto-Fix Protocol

| Issue               | Auto-Fix Action         |
| ------------------- | ----------------------- |
| Lint warnings       | `npm run lint --fix`    |
| TODO/FIXME          | Remove or create ticket |
| Debug prints        | Remove all console.log  |
| Trailing whitespace | Strip via formatter     |
| Unused imports      | Remove automatically    |

After auto-fixes: re-run affected checks. If issues remain → BLOCK.

## SemVer Version Bumping

```
Current: 1.4.2
Bump major (breaking): 2.0.0
Bump minor (feature):  1.5.0
Bump patch (bugfix):   1.4.3
```

## Changelog Format (Keep a Changelog)

```markdown
## [1.5.0] - 2025-01-24

### Added

- New feature description

### Changed

- Updated behavior description

### Fixed

- Bug fix description

### Security

- Security patch description
```

## Rollback Procedures

If release fails in production:

1. `git checkout v{previous}` — revert to previous tag
2. Trigger rollback deployment
3. Notify stakeholders
4. Post-mortem analysis

## Related Agents

- `app-release-manager` — Main release orchestrator
- `thor-quality-assurance-guardian` — Quality gates
