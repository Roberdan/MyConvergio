# Test File Organization

This document categorizes all test files in the tests/ directory.

## Categories

### Core Plan Database Tests
- `plan-db-cluster.test.sh` - Plan database cluster functionality
- `plan-db-core.test.sh` - Core plan database operations
- `plan-db-validate.test.sh` - Plan validation logic
- `test-plan-db-delegate.sh` - Plan database delegation
- `test-plan-db-safe-circuit-breaker.sh` - Circuit breaker for plan-db-safe
- `test-plan-db-schema.sh` - Database schema validation

### Hook Tests
- `test-hook-bash-antipatterns.sh` - Bash antipattern detection
- `test-hook-enforce-line-limit.sh` - Line limit enforcement
- `test-hook-env-vault-guard.sh` - Environment vault protection
- `test-hook-worktree-guard.sh` - Worktree guard hook
- `test-hooks-registration.sh` - Hook registration system
- `test-secret-scanner.sh` - Secret detection in commits
- `test-version-check.sh` - CLI version checking (REFACTORED)

### Worktree Safety Tests
- `test-worktree-check-unit.sh` - Unit tests for worktree checks
- `test-worktree-safety-integration.sh` - Integration tests
- `test-worktree-safety.sh` - Main worktree safety tests (REFACTORED)

### Orchestration Tests
- `test-changelog-orchestrator.sh` - Changelog generation orchestrator
- `test-e2e-orchestrator.sh` - End-to-end orchestrator tests
- `test-install-config-orchestrator.sh` - Installation config orchestrator
- `test-migrate-v7-orchestrator.sh` - Migration orchestrator
- `test-orchestrate.sh` - Main orchestration logic
- `test-orchestrator-setup.sh` - Orchestrator setup
- `test-orchestrator-test.sh` - Orchestrator testing

### Worker Tests
- `test-copilot-worker.sh` - Copilot API worker
- `test-gemini-worker.sh` - Gemini API worker
- `test-opencode-worker.sh` - OpenCode API worker

### Delegation Tests
- `test-dashboard-delegation.sh` - Dashboard delegation
- `test-dashboard-split.sh` - Dashboard splitting logic
- `test-delegate-utils.sh` - Delegation utilities
- `test-delegate.sh` - Core delegation logic
- `test-diana-performance-dashboard-delegation.sh` - Diana performance dashboard

### Agent Tests
- `test-agent-protocol.sh` - Agent protocol compliance
- `test-agent-validation.sh` - Agent validation logic

### Cross-Repo Learning Tests
- `test-cross-repo-learnings-gates.sh` - Learning quality gates
- `test-cross-repo-learnings-problems.sh` - Learning problem detection

### Environment/Config Tests
- `test-env-vault-guard.sh` - Environment vault guard
- `test-env-vault.sh` - Environment vault functionality
- `test-postinstall-profile.sh` - Post-install profile setup

### Quality & Templates
- `test-quality-gate-templates.sh` - Quality gate templates
- `test-adr-0009-format.sh` - ADR 0009 format compliance
- `test-adr-0010.sh` - ADR 0010 compliance
- `test-T6-04-adr-updates.sh` - Task T6-04 ADR updates

### Execution Tests
- `test-execute-plan.sh` - Plan execution logic
- `test-gh-ops-routing.sh` - GitHub operations routing
- `test-model-registry-refresh.sh` - Model registry refresh
- `test-model-registry.sh` - Model registry
- `test-cmd-start-claim.sh` - Start/claim command
- `test-thor-audit-log.sh` - Thor audit logging

### Script Tests
- `scripts/test-script-modularization.sh` - Script modularization

## Refactored Tests (Using test-helpers.sh)

- `test-worktree-safety.sh` - Uses new assertion helpers
- `test-version-check.sh` - Uses new assertion helpers

## Notes

- Tests should use `tests/lib/test-helpers.sh` for common patterns
- All test files should follow SCRIPT_DIR pattern
- Maximum 250 lines per test file
- Use conventional assertions for consistency
