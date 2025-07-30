# Version Management in MyConvergio

This document explains how versioning works in the MyConvergio project, both for the system as a whole and for individual agents.

## Overview

MyConvergio uses a two-level versioning system:

1. **System Version**: Tracks the overall version of the MyConvergio platform
2. **Agent Versions**: Individual versions for each agent, allowing independent updates

## Version Format

Versions follow [Semantic Versioning 2.0.0](https://semver.org/) format:

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
- **PRERELEASE** (optional): Pre-release versions (e.g., alpha, beta, rc)

## Version Manager

The `scripts/version-manager.sh` script provides commands to manage versions:

### Listing Versions

List all agents and their versions:

```bash
./scripts/version-manager.sh list
```

### Updating System Version

Update the system version:

```bash
./scripts/version-manager.sh system-version 1.2.3
```

### Managing Agent Versions

Get an agent's version:

```bash
./scripts/version-manager.sh agent-version ali-chief-of-staff
```

Update an agent's version:

```bash
./scripts/version-manager.sh agent-version ali-chief-of-staff 2.1.0
```

### Scanning for New Agents

Scan the agents directory and update versions for new or modified agents:

```bash
./scripts/version-manager.sh scan
```

## Version File Format

The `VERSION` file stores all version information:

```
# System Version
SYSTEM_VERSION=1.0.0

# Agent versions (name=version timestamp)
ali-chief-of-staff=1.2.3 2025-07-30T10:00:00Z
baccio-tech-architect=2.1.0 2025-07-29T15:30:00Z
```

## Best Practices

1. **Version Bumping**:
   - Bump MAJOR for breaking changes
   - Bump MINOR for new features
   - Bump PATCH for bug fixes

2. **Pre-release Versions**:
   - Use `-alpha.N` for early testing
   - Use `-beta.N` for feature complete testing
   - Use `-rc.N` for release candidates

3. **Version Control**:
   - Commit version changes with descriptive messages
   - Tag releases with the version number (e.g., `v1.2.3`)

## Integration with Deployment

The deployment script (`deploy-agents.sh`) automatically:

1. Checks agent versions during deployment
2. Updates version information in deployed agent files
3. Warns about version mismatches

## Troubleshooting

If you encounter version-related issues:

1. Run `./scripts/version-manager.sh scan` to update version information
2. Check the `VERSION` file for any inconsistencies
3. Verify agent files have the correct version metadata in their frontmatter
