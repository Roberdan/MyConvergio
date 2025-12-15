# ADR-006: GitHub Actions for CI/CD

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Need automated testing, validation, and synchronization with ConvergioCLI repository.

## Decision

Implement four GitHub Actions workflows:

1. **test.yml**: Run tests on PR
2. **sync.yml**: Check for ConvergioCLI updates daily
3. **validate.yml**: Validate Constitution compliance
4. **release.yml**: Auto-release on version tag

## Rationale

1. GitHub Actions is free for public repos
2. Ensures quality before merge
3. Automates tedious sync tasks
4. Enables continuous deployment

## Workflow Details

### test.yml
- Triggers on PR
- Runs `make test`
- Validates agent structure

### sync.yml
- Runs daily at 6am UTC
- Compares agent counts with ConvergioCLI
- Creates issue if sync needed

### validate.yml
- Triggers on push to master/main
- Checks Constitution exists
- Validates required articles
- Checks agent security sections
- Reports model field coverage

### release.yml
- Triggers on version tag (v*)
- Verifies VERSION file matches tag
- Counts agents
- Generates release notes
- Creates GitHub Release

## Consequences

**Positive:**
- Automated quality gates
- Consistent deployments
- Reduced manual work

**Negative:**
- Initial setup effort

## Implementation

- Created `.github/workflows/test.yml`
- Created `.github/workflows/sync.yml`
- Created `.github/workflows/validate.yml`
- Created `.github/workflows/release.yml`
