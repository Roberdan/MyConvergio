# ADR-008: ConvergioCLI as Advanced Version

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Two repositories exist:
- **MyConvergio** (this repo)
- **ConvergioCLI** (https://github.com/Roberdan/convergio-cli)

Need to clarify relationship.

## Decision

- **MyConvergio**: Cloud-based agents for Claude Code CLI (cross-platform)
- **ConvergioCLI**: Advanced local CLI with Apple Silicon optimization, Anna assistant, offline mode

Add "See Also" section in README linking to ConvergioCLI for users wanting advanced features.

## Rationale

1. Different use cases (cloud vs local)
2. ConvergioCLI has features not possible in cloud (offline, local models)
3. Users should know both options exist

## Sync Strategy

- Daily GitHub Action checks for differences
- Manual sync via `scripts/sync-from-convergiocli.sh`
- ConvergioCLI is the upstream source for agent definitions

## Consequences

**Positive:**
- Clear product positioning
- Users can choose based on needs

**Negative:**
- Two repos to maintain (but they sync)

## Implementation

- Added "See Also" section to README.md
- Created `.github/workflows/sync.yml`
- Created `scripts/sync-from-convergiocli.sh`
