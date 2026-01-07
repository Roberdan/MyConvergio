# Claude Code Context Optimization Guide

Last updated: 2026-01-01

## Overview

This document tracks all optimizations made to reduce Claude Code context usage while maintaining functionality.

---

## Optimization Summary

| Category | Before | After | Savings |
|----------|--------|-------|---------|
| **Planner skill** | 605 lines | 149 lines | ~2.5k tokens |
| **CLAUDE.md (project)** | 158 lines | 47 lines | ~1k tokens |
| **Thor agent** | 476 lines | 77 lines | ~1.5k tokens |
| **Paolo agent** | 303 lines | 60 lines | ~800 tokens |
| **Otto agent** | 262 lines | 71 lines | ~600 tokens |
| **Dario agent** | 250 lines | 64 lines | ~600 tokens |
| **feature-dev plugin** | enabled | disabled | 1.2k tokens |
| **code-review plugin** | enabled | disabled | 1.8k tokens |
| **TOTAL** | | | **~10k tokens** |

---

## Files Changed

### Project Level (ExampleProject)

| File | Change |
|------|--------|
| `CLAUDE.md` | Condensed, moved details to docs on-demand |
| `.claudeignore` | Created - excludes node_modules, build, assets, locks |
| `docs/claude/database.md` | New - database details on-demand |
| `docs/claude/api-routes.md` | New - API routes + env vars on-demand |
| `.claude/settings.json` | Disabled feature-dev, code-review plugins |

### User Level (~/.claude)

| File | Change |
|------|--------|
| `settings.json` | Disabled feature-dev, code-review plugins |
| `commands/planner.md` | 75% reduction, kept all functionality |
| `agents/core_utility/thor-quality-assurance-guardian.md` | 84% reduction |
| `agents/technical_development/paolo-best-practices-enforcer.md` | 80% reduction |
| `agents/technical_development/otto-performance-optimizer.md` | 73% reduction |
| `agents/technical_development/dario-debugger.md` | 74% reduction |

---

## Strategies Applied

### 1. `.claudeignore`

Excludes files that should never be in context:

```
node_modules/     # Dependencies (huge, never useful)
.next/, dist/     # Build outputs
*.png, *.jpg      # Binary assets
package-lock.json # Lock files (huge, rarely useful)
coverage/         # Test artifacts
```

### 2. On-Demand Documentation

Moved verbose sections from always-loaded CLAUDE.md to `@docs/claude/*.md`:

- `database.md` - Prisma models, data persistence
- `api-routes.md` - All endpoints, environment vars

Load with: `@docs/claude/database.md`

### 3. Agent Optimization

Reduced agent files by:
- Removing redundant security/ethics boilerplate (covered by constitution)
- Condensing examples into tables
- Keeping only actionable checklists
- Removing verbose explanations

### 4. Plugin Management

Disabled plugins with redundant functionality:
- `feature-dev` → Use custom agents (code-explorer, code-architect)
- `code-review` → Use rex-code-reviewer agent (9x lighter)

Kept:
- `frontend-design` - Unique functionality
- `pr-review-toolkit` - Useful for PR workflows

### 5. Model Selection

Agents already optimized with appropriate models:
- `haiku` - rex, dario, otto, paolo, marco, feature-release-manager
- `sonnet` - thor, baccio, app-release-manager

---

## Future Optimization Options

If more reduction needed:

1. **Consolidate release managers**: app-release-manager + feature-release-manager could merge
2. **Further reduce global CLAUDE.md**: Currently 110 lines, could be 60
3. **Lazy-load skills**: Skills can't be lazy-loaded (always in context if enabled)
4. **Disable more plugins**: frontend-design if rarely used

---

## Verification

After changes, restart Claude Code and run `/context` to verify reduction.

Expected after optimization:
- System overhead: ~18k tokens (down from ~24k)
- Free space: ~105k tokens (up from ~99k)

---

## Rollback

If issues arise, git history preserves all original files:

```bash
# Restore specific file
git checkout HEAD~1 -- path/to/file.md

# View original
git show HEAD~1:path/to/file.md
```
