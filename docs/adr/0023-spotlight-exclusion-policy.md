# ADR 0023: Spotlight Exclusion Policy

**Status**: Accepted
**Date**: 27 Feb 2026

## Context

macOS Spotlight (`mds`/`mdworker`) continuously indexes all files under `~/GitHub` (23GB+, 50+ repos) and `~/.claude`. This causes:

- CPU spikes (15+ mdworker processes) after file changes, worktree creation, npm install
- Battery drain from sustained I/O during indexing
- Zero value: code search is done via IDE (VS Code, Cursor, Zed), CLI (Grep/Glob), or CodeGraph — never Spotlight

## Decision

Exclude `~/GitHub` and `~/.claude` entirely from Spotlight indexing.

**Method**: System Settings > Siri & Spotlight > Spotlight Privacy > add both directories.

No programmatic alternative exists on modern macOS (mdutil doesn't work on user subdirectories, no public API for the privacy list).

## Alternatives Considered

| Approach                                                              | Verdict                                                               |
| --------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Exclude only build artifacts (node_modules, **pycache**, .next, dist) | Too granular — 65+ directories, new ones appear constantly            |
| `.metadata_never_index` marker files                                  | Works per-directory but pollutes repos, doesn't cover new directories |
| Exclude all of `/GitHub` via Spotlight Privacy                        | Chosen — zero maintenance, zero value lost                            |

## Consequences

- Spotlight will not find source code files — acceptable since we never use it for that
- `mdfind` CLI won't work on code files — we use `grep`/`glob`/`codegraph` instead
- Significant battery and CPU savings, especially during plan execution (worktrees, npm install, bulk file edits)

## Maintenance

Script `spotlight-exclude.sh` retained for edge cases (e.g., repos outside `~/GitHub`). Hook `worktree-setup.sh` v1.1.0 calls it as fallback.
