# ADR 0015: AGENTS.md Cross-Tool Standard

**Status**: Accepted
**Date**: 21 Feb 2026
**Plan**: 189

## Context

AI coding tools have converged on standardized instruction files in 2025-2026:

| Tool | Instruction File | Discovery Mechanism |
|------|------------------|---------------------|
| **Claude Code** | CLAUDE.md | Root directory convention |
| **GitHub Copilot CLI** | AGENTS.md | Documented in .github/ spec |
| **Codex CLI** | AGENTS.md | Follows Copilot convention |
| **Gemini Code** | AGENTS.md | Multi-tool compatibility |

Current state:
- `.claude/CLAUDE.md` exists for Claude Code
- No `AGENTS.md` → Copilot/Codex rely on `.github/instructions/*.instructions.md` (fragmented)
- Linux Foundation proposed AGENTS.md as cross-tool standard (Jan 2026)

Problem: Duplicating rules across CLAUDE.md + AGENTS.md wastes tokens and creates drift.

## Decision

### AGENTS.md as Cross-Tool Index

Create `AGENTS.md` at repository root with:

1. **Shared rules** applicable to all tools (TDD, coding standards, git workflow)
2. **Tool-specific references** via `@imports` for lazy-loading
3. **Agent-specific skills** in `agents/` directory

### Content Scope

| Section | Content | Tools That Use It |
|---------|---------|-------------------|
| **Core Rules** | TDD, max 250 lines/file, conventional commits | All (Claude, Copilot, Codex, Gemini) |
| **Tool References** | `@agents/plan-executor.md`, `@agents/claude-code.md` | Specific tool loads on demand |
| **Shared Skills** | `@skills/shell-safety.md`, `@skills/git-workflow.md` | All tools |
| **Project Context** | Tech stack, directory structure, testing framework | All tools |

### CLAUDE.md vs. AGENTS.md

| File | Purpose | Content Strategy |
|------|---------|------------------|
| **CLAUDE.md** | Claude Code-specific entry point | Lightweight index + `@imports` to agents/ |
| **AGENTS.md** | Cross-tool shared rules | Core standards + references to tool-specific agents/ |

### File Structure

- `AGENTS.md` (root) → cross-tool index, core rules, @imports
- `CLAUDE.md` (root) → Claude-specific entry point
- `agents/` → plan-executor.md, claude-code.md, copilot-cli.md, codex-cli.md
- `skills/` → shell-safety.md, git-workflow.md, tdd.md (shared)
- `.github/instructions/` → deprecated (legacy Copilot location)

### Linux Foundation Alignment

Linux Foundation AI Coding Standards (Jan 2026): AGENTS.md canonical name (Markdown), version headers, tool-agnostic core + tool-specific imports.

## Consequences

### Positive
- **Single source of truth**: Core rules in one place, not duplicated
- **Tool portability**: Works across Claude, Copilot, Codex, Gemini
- **Token efficiency**: `@imports` load content only when needed
- **Maintainability**: Update rules once, not per-tool
- **Onboarding**: New tools automatically discover AGENTS.md

### Negative
- **Two entry points**: CLAUDE.md (Claude) + AGENTS.md (others) requires explanation
- **Migration effort**: Existing Copilot users rely on `.github/instructions/`
- **Tool-specific quirks**: Not all tools support `@imports` syntax equally

### Migration Plan

1. Create AGENTS.md with cross-tool rules
2. Refactor CLAUDE.md to lightweight index + @imports
3. Extract shared skills to skills/ directory
4. Deprecate .github/instructions/ (Copilot legacy)
5. Add version headers to instruction files

### Compatibility Matrix

| Tool | AGENTS.md Support | @imports Support | Notes |
|------|-------------------|------------------|-------|
| Claude Code | ✅ Yes (manual discovery) | ✅ Yes | Native `@file` syntax |
| Copilot CLI | ✅ Yes (documented) | ⚠️ Partial | Uses `.github/instructions/` as fallback |
| Codex CLI | ✅ Yes (convention) | ⚠️ Partial | Preloads all markdown in root |
| Gemini Code | ✅ Yes (multi-tool) | ❌ No | Loads full file, no lazy loading |

## File Impact Table

| File | Impact |
|------|--------|
| AGENTS.md | Create (cross-tool index) |
| CLAUDE.md | Refactor to lightweight + @imports |
| agents/plan-executor.md | Extract shared workflow |
| agents/claude-code.md | Claude-specific behaviors |
| agents/copilot-cli.md | Copilot-specific behaviors |
| skills/shell-safety.md | Extract from CLAUDE.md |
| skills/git-workflow.md | Extract from CLAUDE.md |
| README.md | Document AGENTS.md vs. CLAUDE.md |

## References

- Linux Foundation AI Coding Standards (Jan 2026)
- GitHub Copilot CLI Documentation: AGENTS.md spec
- ADR 0009: Compact Markdown Format (token efficiency)
- ADR 0007: CLAUDE.md Restructuring (progressive disclosure)
