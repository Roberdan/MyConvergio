# MyConvergio Agent Versioning Policy

## Overview

MyConvergio implements a comprehensive versioning system for both the overall system and individual agents. This policy ensures transparent tracking of changes, maintains backward compatibility, and provides clear communication of capabilities to users.

**Version**: 1.0.0
**Effective Date**: 2025-12-15
**Last Updated**: 2025-12-15

## Versioning Philosophy

Our versioning approach follows these core principles:

1. **Semantic Versioning**: All versions follow the `MAJOR.MINOR.PATCH` format (SemVer 2.0.0)
2. **Transparent Change Tracking**: Every version bump includes clear documentation in agent changelogs
3. **Independent Agent Versions**: Each agent maintains its own version independent of the system version
4. **User-Facing Transparency**: Agents can report their version when asked about capabilities

## Version Structure

### System Version

The overall MyConvergio system maintains a global version in the `VERSION` file at the repository root.

**Format**: `SYSTEM_VERSION=MAJOR.MINOR.PATCH`

**Managed by**: `scripts/version-manager.sh`

### Agent Versions

Each agent maintains an independent version in its frontmatter YAML header.

**Location**: `.claude/agents/[category]/[agent-name].md`

**Frontmatter Format**:
```yaml
---
name: agent-name
description: Agent description
tools: ["Tool1", "Tool2"]
color: "#HEX_COLOR"
model: "model-name"
version: "1.0.0"
---
```

## Semantic Versioning Rules

### MAJOR Version (X.0.0)

Bump the MAJOR version when you make incompatible changes:

- **Breaking changes to agent behavior** (e.g., fundamental role changes)
- **Removal of core capabilities** (e.g., removing tool access)
- **Incompatible interface changes** (e.g., changing expected input/output formats)
- **Major architectural overhauls** (e.g., complete rewrite of agent logic)

**Example**:
```
1.0.0 → 2.0.0: Baccio transitions from microservices to event-driven architecture focus
```

### MINOR Version (0.X.0)

Bump the MINOR version when you add functionality in a backward-compatible manner:

- **New capabilities or features** (e.g., adding new analysis frameworks)
- **Enhanced tool access** (e.g., adding WebSearch capability)
- **New sections or methodologies** (e.g., adding RACI matrix to orchestration)
- **Significant improvements** (e.g., enhanced quality checking)

**Example**:
```
1.0.0 → 1.1.0: Added advanced multi-agent coordination patterns
```

### PATCH Version (0.0.X)

Bump the PATCH version when you make backward-compatible bug fixes or minor improvements:

- **Bug fixes** (e.g., correcting logic errors)
- **Documentation updates** (e.g., clarifying instructions)
- **Performance optimizations** (e.g., improving response efficiency)
- **Security framework updates** (e.g., strengthening anti-hijacking)
- **Model optimization** (e.g., switching from opus to sonnet for cost efficiency)
- **Minor refinements** (e.g., improving phrasing or examples)

**Example**:
```
1.0.0 → 1.0.1: Fixed bug in version display logic
```

## Version Management Tools

### 1. Version Manager (`scripts/version-manager.sh`)

Central tool for system and agent version management.

**Commands**:
```bash
# List all agent versions
./scripts/version-manager.sh list

# Scan for new agents
./scripts/version-manager.sh scan

# Get/set system version
./scripts/version-manager.sh system-version
./scripts/version-manager.sh system-version 1.1.0

# Get/set agent version
./scripts/version-manager.sh agent-version ali-chief-of-staff
./scripts/version-manager.sh agent-version ali-chief-of-staff 1.2.0
```

### 2. Version Bump Script (`scripts/bump-agent-version.sh`)

Automated tool for bumping agent versions with changelog updates.

**Usage**:
```bash
# Bump single agent
./scripts/bump-agent-version.sh patch ali-chief-of-staff "Fixed orchestration bug"
./scripts/bump-agent-version.sh minor baccio-tech-architect "Added new architecture patterns"
./scripts/bump-agent-version.sh major domik-mckinsey-strategic-decision-maker "Complete ISE framework overhaul"

# Bump all agents at once
./scripts/bump-agent-version.sh --all patch "Security framework updates"
```

**What it does**:
1. Updates version field in agent frontmatter
2. Adds changelog entry with date and description
3. Validates semantic versioning format
4. Provides clear success/error feedback

## Changelog Management

Every agent maintains a changelog section at the end of its file.

**Format**:
```markdown
## Changelog

- **1.2.0** (2025-12-16): Added advanced multi-agent coordination patterns
- **1.1.0** (2025-12-15): Enhanced quality assurance protocols
- **1.0.0** (2025-12-15): Initial security framework and model optimization
```

**Guidelines**:
- Most recent version always appears first
- Each entry includes version, date (YYYY-MM-DD), and clear description
- Descriptions are concise but meaningful (focus on "what" and "why")
- Use present tense for descriptions (e.g., "Add" not "Added")

## Version Display to Users

All agents include version information capability:

**Frontmatter Instruction**:
```markdown
### Version Information
When asked about your version or capabilities, include your current version number from the frontmatter in your response.
```

**Example User Interaction**:
```
User: @ali-chief-of-staff What version are you running?
Ali: I'm currently running version 1.0.0. This version includes the initial security framework,
     multi-agent orchestration capabilities, and full backend data access.
```

## Version Workflow

### Standard Development Cycle

1. **Make Changes**: Update agent file with new capabilities or fixes
2. **Determine Bump Type**: Assess if change is MAJOR, MINOR, or PATCH
3. **Bump Version**: Use `bump-agent-version.sh` with appropriate type
4. **Test Agent**: Verify agent works as expected
5. **Commit Changes**: Include version bump in commit message

**Example Workflow**:
```bash
# 1. Edit agent file
vim .claude/agents/leadership_strategy/ali-chief-of-staff.md

# 2. Bump version with description
./scripts/bump-agent-version.sh minor ali-chief-of-staff "Added RACI matrix for agent coordination"

# 3. Test agent
@ali-chief-of-staff help me coordinate a complex initiative

# 4. Commit
git add .claude/agents/leadership_strategy/ali-chief-of-staff.md
git commit -m "feat(ali): add RACI matrix for agent coordination (v1.1.0)"
```

### Bulk Updates

When applying system-wide changes (e.g., security framework updates):

```bash
# Update all agent files with changes
# ...

# Bump all agents at once
./scripts/bump-agent-version.sh --all patch "Enhanced anti-hijacking protocol"

# Commit
git add .claude/agents/
git commit -m "feat(agents): enhance anti-hijacking protocol across all agents"
```

## Version Tracking in VERSION File

The `VERSION` file at repository root tracks both system and agent versions.

**Format**:
```
# MyConvergio Version Information
SYSTEM_VERSION=1.0.0

# Agent Versions
ali-chief-of-staff=1.0.0 2025-12-15T08:02:31Z
baccio-tech-architect=1.0.0 2025-12-15T08:02:30Z
thor-quality-assurance-guardian=1.0.0 2025-12-15T08:02:31Z
...
```

**Note**: This file is auto-managed by `version-manager.sh` and should not be manually edited.

## Best Practices

### DO

✅ **Always provide meaningful change descriptions**
```bash
./scripts/bump-agent-version.sh patch ali-chief-of-staff "Fix version display in responses"
```

✅ **Bump version AFTER making changes but BEFORE committing**
```bash
# Edit files → Bump version → Test → Commit
```

✅ **Use semantic versioning correctly**
```
Bug fix → PATCH
New feature → MINOR
Breaking change → MAJOR
```

✅ **Keep changelogs concise but descriptive**
```markdown
- **1.1.0** (2025-12-15): Add RACI matrix for multi-agent coordination
```

✅ **Test agents after version bumps**
```bash
@agent-name verify your changes work
```

### DON'T

❌ **Don't manually edit VERSION file**
```
Use version-manager.sh or bump-agent-version.sh instead
```

❌ **Don't skip version bumps for changes**
```
Every change should increment version
```

❌ **Don't use vague change descriptions**
```bash
# Bad
./scripts/bump-agent-version.sh patch ali-chief-of-staff "Updates"

# Good
./scripts/bump-agent-version.sh patch ali-chief-of-staff "Fix orchestration logic for parallel agent calls"
```

❌ **Don't bump version before making changes**
```
Change → Version bump → Test → Commit (correct order)
```

## Version History Queries

Users can query version information:

```bash
# List all versions
./scripts/version-manager.sh list

# Check system version
./scripts/version-manager.sh system-version

# Check specific agent version
./scripts/version-manager.sh agent-version ali-chief-of-staff
```

Agents can also self-report:
```
@ali-chief-of-staff what version are you?
```

## Migration from Pre-Versioned Agents

All agents started at version `1.0.0` on 2025-12-15 with the initial changelog entry:

```markdown
## Changelog

- **1.0.0** (2025-12-15): Initial security framework and model optimization
```

This represents the baseline after implementing:
- Security & Ethics Framework
- Anti-Hijacking Protocol
- Model optimization (opus/sonnet/haiku assignment)
- Tool access rationalization

## Future Considerations

### Pre-Release Versions

For experimental features, use pre-release versioning:
```
1.1.0-alpha
1.1.0-beta
1.1.0-rc1
```

Bump with custom version:
```bash
# Manual frontmatter edit for pre-release
version: "1.1.0-beta"
```

### Deprecation Policy

When deprecating agent capabilities:
1. Announce deprecation in MINOR version
2. Provide migration guidance in changelog
3. Remove in next MAJOR version

Example:
```markdown
- **1.1.0** (2025-12-20): DEPRECATION: Legacy orchestration pattern will be removed in v2.0.0
- **2.0.0** (2025-12-30): BREAKING: Removed legacy orchestration pattern (use RACI matrix)
```

## Support & Questions

For questions about versioning policy:
- Review this document
- Check `scripts/bump-agent-version.sh --help`
- Check `scripts/version-manager.sh help`
- Consult repository maintainers

## Policy Updates

This policy document is versioned alongside the MyConvergio system:
- **1.0.0** (2025-12-15): Initial versioning policy established

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-15
**Maintained By**: MyConvergio Core Team
